// Copyright (c) 2012 Intel Corp
// Copyright (c) 2012 The Chromium Authors
// 
// Permission is hereby granted, free of charge, to any person obtaining a copy 
// of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell co
// pies of the Software, and to permit persons to whom the Software is furnished
//  to do so, subject to the following conditions:
// 
// The above copyright notice and this permission notice shall be included in al
// l copies or substantial portions of the Software.
// 
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IM
// PLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNES
// S FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS
//  OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WH
// ETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
//  CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

#include "content/nw/src/shell.h"

#include <algorithm>
#include <string>

#include "base/command_line.h"
#include "base/logging.h"
#import "base/memory/scoped_nsobject.h"
#include "base/string_piece.h"
#include "base/sys_string_conversions.h"
#include "base/values.h"
#include "content/public/browser/native_web_keyboard_event.h"
#include "content/public/browser/web_contents.h"
#include "content/public/browser/web_contents_view.h"
#include "content/nw/src/common/shell_switches.h"
#include "content/nw/src/nw_package.h"
#include "content/nw/src/resource.h"
#include "googleurl/src/gurl.h"
#import "ui/base/cocoa/underlay_opengl_hosting_window.h"

#if !defined(MAC_OS_X_VERSION_10_7) || \
    MAC_OS_X_VERSION_MAX_ALLOWED < MAC_OS_X_VERSION_10_7

enum {
  NSWindowCollectionBehaviorFullScreenPrimary = 1 << 7,
  NSWindowCollectionBehaviorFullScreenAuxiliary = 1 << 8
};

#endif // MAC_OS_X_VERSION_10_7

// Receives notification that the window is closing so that it can start the
// tear-down process. Is responsible for deleting itself when done.
@interface ContentShellWindowDelegate : NSObject<NSWindowDelegate> {
 @private
  content::Shell* shell_;
}
- (id)initWithShell:(content::Shell*)shell;
@end

@implementation ContentShellWindowDelegate

- (id)initWithShell:(content::Shell*)shell {
  if ((self = [super init])) {
    shell_ = shell;
  }
  return self;
}

// Called when the window is about to close. Perform the self-destruction
// sequence by getting rid of the shell and removing it and the window from
// the various global lists. Instead of doing it here, however, we fire off
// a delayed call to |-cleanup:| to allow everything to get off the stack
// before we go deleting objects. By returning YES, we allow the window to be
// removed from the screen.
- (BOOL)windowShouldClose:(id)window {
  [window autorelease];

  // Clean ourselves up and do the work after clearing the stack of anything
  // that might have the shell on it.
  [self performSelectorOnMainThread:@selector(cleanup:)
                         withObject:window
                      waitUntilDone:NO];

  return YES;
}

// Does the work of removing the window from our various bookkeeping lists
// and gets rid of the shell.
- (void)cleanup:(id)window {
  delete shell_;

  [self release];
}

- (void)performAction:(id)sender {
  shell_->ActionPerformed([sender tag]);
}

- (void)takeURLStringValueFrom:(id)sender {
  shell_->URLEntered(base::SysNSStringToUTF8([sender stringValue]));
}

@end

@interface CrShellWindow : UnderlayOpenGLHostingWindow {
 @private
  content::Shell* shell_;
}
- (void)setShell:(content::Shell*)shell;
- (void)showDevTools:(id)sender;
@end

@implementation CrShellWindow

- (void)setShell:(content::Shell*)shell {
  shell_ = shell;
}

- (void)showDevTools:(id)sender {
  shell_->ShowDevTools();
}

@end

namespace {

// Layout constants (in view coordinates)
const CGFloat kButtonWidth = 72;
const CGFloat kURLBarHeight = 24;

void MakeShellButton(NSRect* rect,
                     NSString* title,
                     NSView* parent,
                     int control,
                     NSView* target,
                     NSString* key,
                     NSUInteger modifier) {
  scoped_nsobject<NSButton> button([[NSButton alloc] initWithFrame:*rect]);
  [button setTitle:title];
  [button setBezelStyle:NSSmallSquareBezelStyle];
  [button setAutoresizingMask:(NSViewMaxXMargin | NSViewMinYMargin)];
  [button setTarget:target];
  [button setAction:@selector(performAction:)];
  [button setTag:control];
  [button setKeyEquivalent:key];
  [button setKeyEquivalentModifierMask:modifier];
  [parent addSubview:button];
  rect->origin.x += kButtonWidth;
}

}  // namespace

namespace content {

void Shell::PlatformInitialize() {
}

void Shell::PlatformCleanUp() {
}

void Shell::PlatformEnableUIControl(UIControl control, bool is_enabled) {
  int id;
  switch (control) {
    case BACK_BUTTON:
      id = IDC_NAV_BACK;
      break;
    case FORWARD_BUTTON:
      id = IDC_NAV_FORWARD;
      break;
    case STOP_BUTTON:
      id = IDC_NAV_STOP;
      break;
    default:
      NOTREACHED() << "Unknown UI control";
      return;
  }
  [[[window_ contentView] viewWithTag:id] setEnabled:is_enabled];
}

void Shell::PlatformSetAddressBarURL(const GURL& url) {
  NSString* url_string = base::SysUTF8ToNSString(url.spec());
  [url_edit_view_ setStringValue:url_string];
}

void Shell::PlatformSetIsLoading(bool loading) {
}

void Shell::PlatformCreateWindow(int width, int height) {
  int window_height = is_toolbar_open_ ? height + kURLBarHeight : height;
  NSRect initial_window_bounds =
      NSMakeRect(0, 0, width, window_height);
  NSRect content_rect = initial_window_bounds;
  NSUInteger style_mask = NSTitledWindowMask |
                          NSClosableWindowMask |
                          NSMiniaturizableWindowMask |
                          NSResizableWindowMask;
  CrShellWindow* window =
      [[CrShellWindow alloc] initWithContentRect:content_rect
                                       styleMask:style_mask
                                         backing:NSBackingStoreBuffered
                                           defer:NO];
  [window setShell:this];
  window_ = window;
  NSView* content = [window_ contentView];

  std::string title = "node-webkit";
  if (window_manifest_) {
    // window.min_height and window.min_width
    if (min_height_ > 0 || min_width_ > 0) {
      min_height_ = min_height_ > 0 ? min_height_ : height;
      min_width_ = min_width_ > 0 ? min_width_ : width;

      NSSize min_size = NSMakeSize(min_width_, min_height_);
      [window_ setContentMinSize:[content convertSize:min_size toView:nil]];
    }

    // window.max_height and window.max_width
    if (max_height_ > 0 || max_width_ > 0) {
      max_height_ = max_height_ > 0 ? max_height_ : height;
      max_width_ = max_width_ > 0 ? max_width_ : width;

      NSSize max_size = NSMakeSize(max_width_, max_height_);
      [window_ setContentMaxSize:[content convertSize:max_size toView:nil]];
    }

    // window.x and window.y
    int x, y;
    if (window_manifest_->GetInteger(switches::kmX, &x) &&
        window_manifest_->GetInteger(switches::kmY, &y)) {
      Move(gfx::Rect(x, y, width, height));
    } else {
      // window.position
      std::string position_string;
      if (window_manifest_->GetString(switches::kmPosition, &position_string) &&
          position_string == "center") {
        [window_ center];
      }
    }

    // window.title
    window_manifest_->GetString(switches::kmTitle, &title);
  }

  [window_ setTitle:[[NSString alloc] initWithUTF8String:title.c_str()]];

  // Set the shell window to participate in Lion Fullscreen mode. Set
  // Setting this flag has no effect on Snow Leopard or earlier.
  NSUInteger collectionBehavior = [window_ collectionBehavior];
  collectionBehavior |= NSWindowCollectionBehaviorFullScreenPrimary;
  [window_ setCollectionBehavior:collectionBehavior];

  // Rely on the window delegate to clean us up rather than immediately
  // releasing when the window gets closed. We use the delegate to do
  // everything from the autorelease pool so the shell isn't on the stack
  // during cleanup (ie, a window close from javascript).
  [window_ setReleasedWhenClosed:NO];

  // Create a window delegate to watch for when it's asked to go away. It will
  // clean itself up so we don't need to hold a reference.
  ContentShellWindowDelegate* delegate =
      [[ContentShellWindowDelegate alloc] initWithShell:this];
  [window_ setDelegate:delegate];

  if (is_toolbar_open_) {
    NSRect button_frame =
        NSMakeRect(0, NSMaxY(initial_window_bounds) - kURLBarHeight,
                   kButtonWidth, kURLBarHeight);

    MakeShellButton(&button_frame, @"Back", content, IDC_NAV_BACK,
                    (NSView*)delegate, @"[", NSCommandKeyMask);
    MakeShellButton(&button_frame, @"Forward", content, IDC_NAV_FORWARD,
                    (NSView*)delegate, @"]", NSCommandKeyMask);
    MakeShellButton(&button_frame, @"Reload", content, IDC_NAV_RELOAD,
                    (NSView*)delegate, @"r", NSCommandKeyMask);
    MakeShellButton(&button_frame, @"Stop", content, IDC_NAV_STOP,
                    (NSView*)delegate, @".", NSCommandKeyMask);

    button_frame.size.width =
        NSWidth(initial_window_bounds) - NSMinX(button_frame);
    scoped_nsobject<NSTextField> url_edit_view(
        [[NSTextField alloc] initWithFrame:button_frame]);
    [content addSubview:url_edit_view];
    [url_edit_view setAutoresizingMask:(NSViewWidthSizable | NSViewMinYMargin)];
    [url_edit_view setTarget:delegate];
    [url_edit_view setAction:@selector(takeURLStringValueFrom:)];
    [[url_edit_view cell] setWraps:NO];
    [[url_edit_view cell] setScrollable:YES];
    url_edit_view_ = url_edit_view.get();
  }

  // Show Debug menu wish --developer
  if (!is_show_devtools_) {
    NSMenu* mainMenu = [NSApp mainMenu];
    int index = [mainMenu indexOfItemWithTitle:@"Debug"];
    if (index != -1)
      [mainMenu removeItemAtIndex:index];
  }

  // Replace all node-webkit stuff to app's name
  base::DictionaryValue* manifest = nw::GetManifest();
  std::string name;
  if (manifest->GetString(switches::kmName, &name) &&
     name != "node-webkit") {
    NSString* nsname = [NSString stringWithUTF8String:name.c_str()];
    // Sub main menus
    NSMenu* menu = [NSApp mainMenu];
    int total = [menu numberOfItems];
    for (int i = 0; i < total; ++i) {
      NSMenuItem* item = [menu itemAtIndex:i];

      if ([item hasSubmenu]) {
        NSMenu* submenu = [item submenu];
        // items of sub main menu
        int total = [submenu numberOfItems];
        for (int j = 0; j < total; ++j) {
          NSMenuItem* item = [submenu itemAtIndex:j];
          NSString* title = item.title;

          NSRange aRange = [title rangeOfString:@"node-webkit"];
          if (aRange.location != NSNotFound)
            [item setTitle:[title stringByReplacingOccurrencesOfString:@"node-webkit"
                                  withString:nsname]];
        }
      }
    }
  }

  // show the window
  [window_ makeKeyAndOrderFront:nil];
}

void Shell::PlatformSetContents() {
  NSView* web_view = web_contents_->GetView()->GetNativeView();
  NSView* content = [window_ contentView];
  [content addSubview:web_view];

  NSRect frame = [content bounds];
  if (is_toolbar_open_) {
    frame.size.height -= kURLBarHeight;
  }
  [web_view setFrame:frame];
  [web_view setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
  [web_view setNeedsDisplay:YES];
}

void Shell::PlatformResizeSubViews() {
  // Not needed; subviews are bound.
}

void Shell::PlatformSetTitle(const string16& title) {
  NSString* title_string = base::SysUTF16ToNSString(title);
  [window_ setTitle:title_string];
}

void Shell::Close() {
  [window_ performClose:nil];
}

void Shell::Move(const gfx::Rect& pos) {
  NSRect cocoa_bounds = NSMakeRect(pos.x(), 0,
                                   pos.width(),
                                   pos.height());
  // Flip coordinates based on the primary screen.
  NSScreen* screen = [[NSScreen screens] objectAtIndex:0];
  cocoa_bounds.origin.y =
      NSHeight([screen frame]) - pos.height() - pos.y();

  [window_ setFrame:cocoa_bounds display:YES];
}

void Shell::Focus(bool focus) {
  if (focus)
    [window_ makeKeyAndOrderFront:window_];
  else
    [window_ orderBack:window_];
}

void Shell::Show(bool show) {
}

void Shell::ActionPerformed(int control) {
  switch (control) {
    case IDC_NAV_BACK:
      GoBackOrForward(-1);
      break;
    case IDC_NAV_FORWARD:
      GoBackOrForward(1);
      break;
    case IDC_NAV_RELOAD:
      Reload();
      break;
    case IDC_NAV_STOP:
      Stop();
      break;
  }
}

void Shell::URLEntered(std::string url_string) {
  if (!url_string.empty()) {
    GURL url(url_string);
    if (!url.has_scheme())
      url = GURL("http://" + url_string);
    LoadURL(url);
  }
}

void Shell::HandleKeyboardEvent(WebContents* source,
                                const NativeWebKeyboardEvent& event) {
  if (event.skip_in_browser)
    return;

  // The event handling to get this strictly right is a tangle; cheat here a bit
  // by just letting the menus have a chance at it.
  if ([event.os_event type] == NSKeyDown) {
    if (is_toolbar_open_ &&
        ([event.os_event modifierFlags] & NSCommandKeyMask) &&
        [[event.os_event characters] isEqual:@"l"]) {
      [window_ makeFirstResponder:url_edit_view_];
      return;
    }

    [[NSApp mainMenu] performKeyEquivalent:event.os_event];
  }
}

}  // namespace content
