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

#ifndef CONTENT_NW_SRC_API_UTILS_H_
#define CONTENT_NW_SRC_API_UTILS_H_

#include "v8/include/v8.h"

namespace content {
class RenderView;
class Shell;
}

namespace api {

v8::Handle<v8::Value> CallMethod(v8::Handle<v8::Value> object,
                                 const char* method,
                                 int argc,
                                 v8::Handle<v8::Value> argv[]);

// Get renderer view from V8 context
int GetCurrentRenderViewInRenderer();

// Get Shell from render view id
content::Shell* GetShellFromRenderViewInUI(int);

}  // namespace api

#endif  // CONTENT_NW_SRC_API_V8_UTILS_H_

