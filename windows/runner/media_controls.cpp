#include "media_controls.h"

#include <flutter/standard_method_codec.h>
#include <systemmediatransportcontrolsinterop.h>

#pragma warning(push, 0)
#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Media.h>
#include <winrt/Windows.Storage.h>
#include <winrt/Windows.Storage.Streams.h>
#pragma warning(pop)

#include <string>

#include "utils.h"

namespace {

using flutter::EncodableMap;
using flutter::EncodableValue;
using winrt::Windows::Media::MediaPlaybackStatus;
using winrt::Windows::Media::MediaPlaybackType;
using winrt::Windows::Media::SystemMediaTransportControls;
using winrt::Windows::Media::SystemMediaTransportControlsButton;
using winrt::Windows::Media::SystemMediaTransportControlsButtonPressedEventArgs;

// Button presses arrive on a background thread, and Flutter's channels must be
// used on the platform thread, so they're posted to the window as this message.
constexpr UINT kButtonMessage = WM_APP + 77;

std::wstring Wide(const std::string& utf8) {
  if (utf8.empty()) return {};
  const int size = MultiByteToWideChar(CP_UTF8, 0, utf8.data(),
                                       static_cast<int>(utf8.size()), nullptr, 0);
  std::wstring wide(size, L'\0');
  MultiByteToWideChar(CP_UTF8, 0, utf8.data(), static_cast<int>(utf8.size()),
                      wide.data(), size);
  return wide;
}

std::string Text(const EncodableMap& map, const char* key) {
  const auto it = map.find(EncodableValue(key));
  if (it == map.end()) return {};
  const auto* value = std::get_if<std::string>(&it->second);
  return value ? *value : std::string();
}

bool Flag(const EncodableMap& map, const char* key) {
  const auto it = map.find(EncodableValue(key));
  if (it == map.end()) return false;
  const auto* value = std::get_if<bool>(&it->second);
  return value && *value;
}

const char* CommandFor(SystemMediaTransportControlsButton button) {
  switch (button) {
    case SystemMediaTransportControlsButton::Play:
      return "play";
    case SystemMediaTransportControlsButton::Pause:
      return "pause";
    case SystemMediaTransportControlsButton::Next:
      return "next";
    case SystemMediaTransportControlsButton::Previous:
      return "previous";
    case SystemMediaTransportControlsButton::Stop:
      return "pause";
    default:
      return nullptr;
  }
}

}  // namespace

struct MediaControls::Impl {
  SystemMediaTransportControls controls{nullptr};
  winrt::event_token token{};
  std::string shown_cover;
};

MediaControls::MediaControls(HWND window, flutter::BinaryMessenger* messenger)
    : impl_(std::make_unique<Impl>()) {
  channel_ = std::make_unique<flutter::MethodChannel<EncodableValue>>(
      messenger, "teleplayer/media_controls",
      &flutter::StandardMethodCodec::GetInstance());

  try {
    auto interop = winrt::get_activation_factory<
        SystemMediaTransportControls, ISystemMediaTransportControlsInterop>();
    winrt::check_hresult(interop->GetForWindow(
        window, winrt::guid_of<SystemMediaTransportControls>(),
        winrt::put_abi(impl_->controls)));
    impl_->controls.IsEnabled(true);
    impl_->controls.IsPlayEnabled(true);
    impl_->controls.IsPauseEnabled(true);
    impl_->controls.IsNextEnabled(true);
    impl_->controls.IsPreviousEnabled(true);
    impl_->controls.IsStopEnabled(true);
    impl_->token = impl_->controls.ButtonPressed(
        [window](SystemMediaTransportControls const&,
                 SystemMediaTransportControlsButtonPressedEventArgs const& args) {
          PostMessage(window, kButtonMessage,
                      static_cast<WPARAM>(args.Button()), 0);
        });
  } catch (...) {
    // Without them the app still plays; only system media keys are lost.
    impl_->controls = nullptr;
  }

  channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<EncodableValue>> result) {
        const auto* args = std::get_if<EncodableMap>(call.arguments());
        if (call.method_name() != "update" || args == nullptr) {
          result->NotImplemented();
          return;
        }
        auto controls = impl_->controls;
        if (!controls) {
          result->Success();
          return;
        }
        try {
          controls.PlaybackStatus(Flag(*args, "playing")
                                      ? MediaPlaybackStatus::Playing
                                      : MediaPlaybackStatus::Paused);
          auto updater = controls.DisplayUpdater();
          updater.Type(MediaPlaybackType::Music);
          auto music = updater.MusicProperties();
          music.Title(Wide(Text(*args, "title")));
          music.Artist(Wide(Text(*args, "artist")));
          music.AlbumTitle(Wide(Text(*args, "album")));
          updater.Update();

          const std::string cover = Text(*args, "cover");
          if (cover != impl_->shown_cover) {
            impl_->shown_cover = cover;
            if (cover.empty()) {
              updater.Thumbnail(nullptr);
              updater.Update();
            } else {
              using winrt::Windows::Foundation::AsyncStatus;
              using winrt::Windows::Foundation::IAsyncOperation;
              using winrt::Windows::Storage::StorageFile;
              using winrt::Windows::Storage::Streams::RandomAccessStreamReference;
              // Not waited on: blocking this thread on it would freeze the window.
              StorageFile::GetFileFromPathAsync(Wide(cover))
                  .Completed([updater](IAsyncOperation<StorageFile> const& op,
                                       AsyncStatus status) {
                    if (status != AsyncStatus::Completed) return;
                    try {
                      updater.Thumbnail(
                          RandomAccessStreamReference::CreateFromFile(op.GetResults()));
                      updater.Update();
                    } catch (...) {
                      // The song stays listed, without its picture.
                    }
                  });
            }
          }
        } catch (...) {
          // Not worth failing playback over.
        }
        result->Success();
      });
}

MediaControls::~MediaControls() {
  if (impl_->controls) {
    try {
      impl_->controls.ButtonPressed(impl_->token);
      impl_->controls.IsEnabled(false);
    } catch (...) {
      // The window is going away anyway.
    }
  }
}

bool MediaControls::HandleMessage(UINT message, WPARAM wparam) {
  if (message != kButtonMessage) return false;
  const char* command =
      CommandFor(static_cast<SystemMediaTransportControlsButton>(wparam));
  if (command) channel_->InvokeMethod(command, nullptr);
  return true;
}
