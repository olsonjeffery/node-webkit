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

#ifndef CONTENT_NW_SRC_API_WINDOW_WINDOW_H_
#define CONTENT_NW_SRC_API_WINDOW_WINDOW_H_ 

#include "third_party/node/src/node.h"

namespace content {
class Shell;
}

namespace api {

class Window {
 public:
  static void Init(v8::Handle<v8::Object> target);

 private:
  Window();
  ~Window();

  // Shared implementations
  static v8::Handle<v8::Value> Show(const v8::Arguments& args);
  static v8::Handle<v8::Value> Hide(const v8::Arguments& args);
};

}  // namespace api

#endif  // CONTENT_NW_SRC_API_WINDOW_WINDOW_H_
