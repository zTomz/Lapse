#include <flutter/dart_project.h>
#include <flutter/flutter_engine.h>
#include <flutter/generated_plugin_registrant.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <dwmapi.h>
#include <shellapi.h>
#include <windows.h>
#include <wtsapi32.h>

#include <chrono>
#include <iterator>
#include <memory>
#include <optional>
#include <sstream>
#include <string>

#include "resource.h"
#include "utils.h"

namespace {

constexpr wchar_t kNotificationClass[] = L"LAPSE_NOTIFICATION_WINDOW";
constexpr wchar_t kOverlayTitle[] = L"Lapse";
constexpr wchar_t kAutostartKey[] =
    L"Software\\Microsoft\\Windows\\CurrentVersion\\Run";
constexpr wchar_t kAutostartValue[] = L"Lapse";
constexpr UINT kTrayMessage = WM_APP + 1;
constexpr UINT kMenuOpen = 1001;
constexpr UINT kMenuToggle = 1002;
constexpr UINT kMenuAutostart = 1003;
constexpr UINT kMenuTopmost = 1004;
constexpr UINT kMenuQuit = 1005;

std::shared_ptr<flutter::MethodChannel<flutter::EncodableValue>> g_channel;
HWND g_notification_window = nullptr;
HWND g_overlay_window = nullptr;
NOTIFYICONDATA g_tray_icon{};
bool g_locked = false;
bool g_sleeping = false;
bool g_collapsed = false;
bool g_autostart = true;
bool g_topmost = true;

void SendEvent(const std::string& event) {
  if (g_channel) {
    g_channel->InvokeMethod(
        "nativeEvent", std::make_unique<flutter::EncodableValue>(event));
  }
}

BOOL CALLBACK FindOverlayCallback(HWND window, LPARAM data) {
  DWORD process_id = 0;
  GetWindowThreadProcessId(window, &process_id);
  if (process_id != GetCurrentProcessId()) {
    return TRUE;
  }
  wchar_t title[128]{};
  GetWindowText(window, title, static_cast<int>(std::size(title)));
  if (wcscmp(title, kOverlayTitle) == 0) {
    *reinterpret_cast<HWND*>(data) = window;
    return FALSE;
  }
  return TRUE;
}

HWND FindOverlayWindow() {
  if (g_overlay_window && IsWindow(g_overlay_window)) {
    return g_overlay_window;
  }
  HWND result = nullptr;
  EnumWindows(FindOverlayCallback, reinterpret_cast<LPARAM>(&result));
  g_overlay_window = result;
  return result;
}

bool IsVisiblePosition(int x, int y, int width, int height) {
  RECT rectangle{x, y, x + width, y + height};
  return MonitorFromRect(&rectangle, MONITOR_DEFAULTTONULL) != nullptr;
}

void ConfigureOverlay(bool always_on_top, std::optional<int> x,
                      std::optional<int> y) {
  HWND overlay = FindOverlayWindow();
  if (!overlay) {
    return;
  }

  LONG_PTR style = GetWindowLongPtr(overlay, GWL_STYLE);
  style &= ~(WS_CAPTION | WS_THICKFRAME | WS_MINIMIZEBOX | WS_MAXIMIZEBOX |
             WS_SYSMENU);
  style |= WS_POPUP;
  SetWindowLongPtr(overlay, GWL_STYLE, style);

  LONG_PTR extended_style = GetWindowLongPtr(overlay, GWL_EXSTYLE);
  extended_style |= WS_EX_TOOLWINDOW;
  extended_style &= ~WS_EX_APPWINDOW;
  SetWindowLongPtr(overlay, GWL_EXSTYLE, extended_style);

  constexpr DWORD corner_preference = 2;  // DWMWCP_ROUND
  DwmSetWindowAttribute(overlay, 33, &corner_preference,
                        sizeof(corner_preference));

  RECT current{};
  GetWindowRect(overlay, &current);
  const int width = current.right - current.left;
  const int height = current.bottom - current.top;
  int target_x = x.value_or(current.left);
  int target_y = y.value_or(current.top);

  if (!x || !y || !IsVisiblePosition(target_x, target_y, width, height)) {
    MONITORINFO monitor_info{sizeof(MONITORINFO)};
    GetMonitorInfo(MonitorFromPoint({0, 0}, MONITOR_DEFAULTTOPRIMARY),
                   &monitor_info);
    target_x = monitor_info.rcWork.right - width - 18;
    target_y = monitor_info.rcWork.top + 18;
  }

  g_topmost = always_on_top;
  SetWindowPos(overlay, always_on_top ? HWND_TOPMOST : HWND_NOTOPMOST, target_x,
               target_y, width, height,
               SWP_FRAMECHANGED | SWP_NOACTIVATE | SWP_SHOWWINDOW);
}

bool IsAutostartEnabled() {
  HKEY key = nullptr;
  if (RegOpenKeyEx(HKEY_CURRENT_USER, kAutostartKey, 0, KEY_QUERY_VALUE,
                   &key) != ERROR_SUCCESS) {
    return false;
  }
  const LONG result = RegQueryValueEx(key, kAutostartValue, nullptr, nullptr,
                                      nullptr, nullptr);
  RegCloseKey(key);
  return result == ERROR_SUCCESS;
}

bool SetAutostartEnabled(bool enabled) {
  HKEY key = nullptr;
  if (RegCreateKeyEx(HKEY_CURRENT_USER, kAutostartKey, 0, nullptr, 0,
                     KEY_SET_VALUE, nullptr, &key, nullptr) != ERROR_SUCCESS) {
    return false;
  }
  LONG result = ERROR_SUCCESS;
  if (enabled) {
    wchar_t executable[MAX_PATH]{};
    GetModuleFileName(nullptr, executable, MAX_PATH);
    const std::wstring command = L"\"" + std::wstring(executable) + L"\"";
    result = RegSetValueEx(
        key, kAutostartValue, 0, REG_SZ,
        reinterpret_cast<const BYTE*>(command.c_str()),
        static_cast<DWORD>((command.size() + 1) * sizeof(wchar_t)));
  } else {
    result = RegDeleteValue(key, kAutostartValue);
    if (result == ERROR_FILE_NOT_FOUND) {
      result = ERROR_SUCCESS;
    }
  }
  RegCloseKey(key);
  return result == ERROR_SUCCESS;
}

void AddTrayIcon() {
  if (g_tray_icon.cbSize != 0) {
    return;
  }
  g_tray_icon.cbSize = sizeof(NOTIFYICONDATA);
  g_tray_icon.hWnd = g_notification_window;
  g_tray_icon.uID = 1;
  g_tray_icon.uFlags = NIF_MESSAGE | NIF_ICON | NIF_TIP;
  g_tray_icon.uCallbackMessage = kTrayMessage;
  g_tray_icon.hIcon = LoadIcon(GetModuleHandle(nullptr),
                               MAKEINTRESOURCE(IDI_APP_ICON));
  wcscpy_s(g_tray_icon.szTip, L"Lapse — active time");
  Shell_NotifyIcon(NIM_ADD, &g_tray_icon);
  g_tray_icon.uVersion = NOTIFYICON_VERSION_4;
  Shell_NotifyIcon(NIM_SETVERSION, &g_tray_icon);
}

void ShowTrayMenu() {
  POINT cursor{};
  GetCursorPos(&cursor);
  HMENU menu = CreatePopupMenu();
  AppendMenu(menu, MF_STRING, kMenuOpen, L"Open Lapse");
  AppendMenu(menu, MF_STRING, kMenuToggle,
             g_collapsed ? L"Expand" : L"Collapse");
  AppendMenu(menu, MF_STRING | (g_autostart ? MF_CHECKED : 0), kMenuAutostart,
             L"Start with Windows");
  AppendMenu(menu, MF_STRING | (g_topmost ? MF_CHECKED : 0), kMenuTopmost,
             L"Always on top");
  AppendMenu(menu, MF_SEPARATOR, 0, nullptr);
  AppendMenu(menu, MF_STRING, kMenuQuit, L"Quit Lapse");
  SetForegroundWindow(g_notification_window);
  const UINT selected = TrackPopupMenu(
      menu, TPM_RETURNCMD | TPM_NONOTIFY | TPM_RIGHTBUTTON, cursor.x, cursor.y,
      0, g_notification_window, nullptr);
  DestroyMenu(menu);
  switch (selected) {
    case kMenuOpen:
      SendEvent("trayOpen");
      break;
    case kMenuToggle:
      SendEvent("trayToggle");
      break;
    case kMenuAutostart:
      SendEvent("trayAutostart");
      break;
    case kMenuTopmost:
      SendEvent("trayTopmost");
      break;
    case kMenuQuit:
      SendEvent("trayQuit");
      break;
  }
}

LRESULT CALLBACK NotificationWindowProc(HWND window, UINT message,
                                        WPARAM wparam, LPARAM lparam) {
  switch (message) {
    case WM_WTSSESSION_CHANGE:
      if (wparam == WTS_SESSION_LOCK) {
        g_locked = true;
        SendEvent("locked");
      } else if (wparam == WTS_SESSION_UNLOCK) {
        g_locked = false;
        SendEvent("unlocked");
      }
      return 0;
    case WM_POWERBROADCAST:
      if (wparam == PBT_APMSUSPEND) {
        g_sleeping = true;
        SendEvent("suspend");
      } else if (wparam == PBT_APMRESUMEAUTOMATIC ||
                 wparam == PBT_APMRESUMESUSPEND) {
        g_sleeping = false;
        SendEvent("resume");
      }
      return TRUE;
    case kTrayMessage:
      if (LOWORD(lparam) == WM_LBUTTONUP) {
        SendEvent("trayOpen");
      } else if (LOWORD(lparam) == WM_CONTEXTMENU ||
                 LOWORD(lparam) == WM_RBUTTONUP) {
        ShowTrayMenu();
      }
      return 0;
  }
  return DefWindowProc(window, message, wparam, lparam);
}

HWND CreateNotificationWindow(HINSTANCE instance) {
  WNDCLASS window_class{};
  window_class.lpfnWndProc = NotificationWindowProc;
  window_class.hInstance = instance;
  window_class.lpszClassName = kNotificationClass;
  RegisterClass(&window_class);
  HWND window = CreateWindowEx(0, kNotificationClass, L"Lapse notifications",
                               0, 0, 0, 0, 0, HWND_MESSAGE, nullptr, instance,
                               nullptr);
  WTSRegisterSessionNotification(window, NOTIFY_FOR_THIS_SESSION);
  return window;
}

template <typename T>
std::optional<T> Argument(const flutter::EncodableMap* arguments,
                          const char* key) {
  if (!arguments) {
    return std::nullopt;
  }
  const auto iterator = arguments->find(flutter::EncodableValue(key));
  if (iterator == arguments->end()) {
    return std::nullopt;
  }
  if (const auto* value = std::get_if<T>(&iterator->second)) {
    return *value;
  }
  return std::nullopt;
}

void RegisterLapseChannel(flutter::FlutterEngine* engine) {
  g_channel = std::make_shared<flutter::MethodChannel<flutter::EncodableValue>>(
      engine->messenger(), "dev.lapse/windows",
      &flutter::StandardMethodCodec::GetInstance());
  g_channel->SetMethodCallHandler(
      [](const flutter::MethodCall<flutter::EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        const auto* arguments = std::get_if<flutter::EncodableMap>(call.arguments());
        if (call.method_name() == "activitySnapshot") {
          LASTINPUTINFO last_input{sizeof(LASTINPUTINFO)};
          DWORD idle = 0;
          if (GetLastInputInfo(&last_input)) {
            idle = GetTickCount() - last_input.dwTime;
          }
          result->Success(flutter::EncodableValue(flutter::EncodableMap{
              {flutter::EncodableValue("idleMilliseconds"),
               flutter::EncodableValue(static_cast<int64_t>(idle))},
              {flutter::EncodableValue("locked"),
               flutter::EncodableValue(g_locked)},
              {flutter::EncodableValue("sleeping"),
               flutter::EncodableValue(g_sleeping)},
          }));
        } else if (call.method_name() == "bootId") {
          FILETIME file_time{};
          GetSystemTimeAsFileTime(&file_time);
          ULARGE_INTEGER current{};
          current.LowPart = file_time.dwLowDateTime;
          current.HighPart = file_time.dwHighDateTime;
          const uint64_t boot_minute =
              (current.QuadPart / 10000ULL - GetTickCount64()) / 60000ULL;
          result->Success(flutter::EncodableValue(std::to_string(boot_minute)));
        } else if (call.method_name() == "configureOverlay") {
          const bool topmost = Argument<bool>(arguments, "alwaysOnTop").value_or(true);
          const auto x = Argument<double>(arguments, "x");
          const auto y = Argument<double>(arguments, "y");
          ConfigureOverlay(topmost, x ? std::optional<int>(static_cast<int>(*x)) : std::nullopt,
                           y ? std::optional<int>(static_cast<int>(*y)) : std::nullopt);
          AddTrayIcon();
          result->Success();
        } else if (call.method_name() == "beginDrag") {
          HWND overlay = FindOverlayWindow();
          if (!overlay) {
            result->Success();
            return;
          }
          ReleaseCapture();
          SendMessage(overlay, WM_NCLBUTTONDOWN, HTCAPTION, 0);
          RECT rect{};
          GetWindowRect(overlay, &rect);
          result->Success(flutter::EncodableValue(flutter::EncodableMap{
              {flutter::EncodableValue("x"),
               flutter::EncodableValue(static_cast<double>(rect.left))},
              {flutter::EncodableValue("y"),
               flutter::EncodableValue(static_cast<double>(rect.top))},
          }));
        } else if (call.method_name() == "resize") {
          HWND overlay = FindOverlayWindow();
          if (overlay) {
            const double width = Argument<double>(arguments, "width").value_or(312);
            const double height = Argument<double>(arguments, "height").value_or(356);
            const UINT dpi = GetDpiForWindow(overlay);
            SetWindowPos(overlay, nullptr, 0, 0,
                         static_cast<int>(width * dpi / 96.0),
                         static_cast<int>(height * dpi / 96.0),
                         SWP_NOMOVE | SWP_NOZORDER | SWP_NOACTIVATE);
          }
          result->Success();
        } else if (call.method_name() == "show") {
          HWND overlay = FindOverlayWindow();
          if (overlay) {
            ShowWindow(overlay, SW_SHOWNOACTIVATE);
            SetWindowPos(overlay, g_topmost ? HWND_TOPMOST : HWND_NOTOPMOST, 0,
                         0, 0, 0,
                         SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE);
          }
          result->Success();
        } else if (call.method_name() == "hide") {
          HWND overlay = FindOverlayWindow();
          if (overlay) {
            ShowWindow(overlay, SW_HIDE);
          }
          result->Success();
        } else if (call.method_name() == "setAlwaysOnTop") {
          g_topmost = std::get<bool>(*call.arguments());
          HWND overlay = FindOverlayWindow();
          if (overlay) {
            SetWindowPos(overlay, g_topmost ? HWND_TOPMOST : HWND_NOTOPMOST, 0,
                         0, 0, 0,
                         SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE);
          }
          result->Success();
        } else if (call.method_name() == "isAutostartEnabled") {
          result->Success(flutter::EncodableValue(IsAutostartEnabled()));
        } else if (call.method_name() == "setAutostartEnabled") {
          g_autostart = std::get<bool>(*call.arguments());
          if (SetAutostartEnabled(g_autostart)) {
            result->Success();
          } else {
            result->Error("autostart", "Unable to update the Windows startup entry");
          }
        } else if (call.method_name() == "updateTray") {
          g_collapsed = Argument<bool>(arguments, "collapsed").value_or(false);
          g_autostart = Argument<bool>(arguments, "autostart").value_or(true);
          g_topmost = Argument<bool>(arguments, "alwaysOnTop").value_or(true);
          AddTrayIcon();
          result->Success();
        } else if (call.method_name() == "quit") {
          if (g_tray_icon.cbSize != 0) {
            Shell_NotifyIcon(NIM_DELETE, &g_tray_icon);
          }
          HWND overlay = FindOverlayWindow();
          if (overlay) {
            DestroyWindow(overlay);
          }
          PostQuitMessage(0);
          result->Success();
        } else {
          result->NotImplemented();
        }
      });
}

}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t* command_line, _In_ int show_command) {
  if (!AttachConsole(ATTACH_PARENT_PROCESS) && IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }
  CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");
  auto command_line_arguments = GetCommandLineArguments();
  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  auto engine = std::make_shared<flutter::FlutterEngine>(project);
  RegisterPlugins(engine.get());
  RegisterLapseChannel(engine.get());
  g_notification_window = CreateNotificationWindow(instance);
  engine->Run();

  MSG message;
  while (GetMessage(&message, nullptr, 0, 0)) {
    TranslateMessage(&message);
    DispatchMessage(&message);
  }

  if (g_notification_window) {
    WTSUnRegisterSessionNotification(g_notification_window);
    DestroyWindow(g_notification_window);
  }
  CoUninitialize();
  return EXIT_SUCCESS;
}
