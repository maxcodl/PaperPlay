#ifndef RUNNER_MEDIA_CONTROLS_H_
#define RUNNER_MEDIA_CONTROLS_H_

#include <flutter/binary_messenger.h>
#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <windows.h>

#include <memory>

// Registers the app with Windows as a media player, so hardware media keys work
// while it isn't focused, and the system's media flyout shows the current song.
class MediaControls {
 public:
  MediaControls(HWND window, flutter::BinaryMessenger* messenger);
  ~MediaControls();

  // Handles the message posted when a media button is pressed. Returns whether
  // the message was one of ours.
  bool HandleMessage(UINT message, WPARAM wparam);

 private:
  struct Impl;
  std::unique_ptr<Impl> impl_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
};

#endif  // RUNNER_MEDIA_CONTROLS_H_
