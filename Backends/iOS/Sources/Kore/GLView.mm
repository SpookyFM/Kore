#import "GLView.h"
#include "pch.h"
#include <Kore/Application.h>
#include <Kore/Input/Keyboard.h>
#include <Kore/Input/Mouse.h>
#include <Kore/Input/Sensor.h>
#include <Kore/Input/Surface.h>
#include <Kore/System.h>

namespace {
	const int touchmaxcount = 20;
	void* touches[touchmaxcount];

	void initTouches() {
		for (int i = 0; i < touchmaxcount; ++i) {
			touches[i] = nullptr;
		}
	}
	
	int getTouchIndex(void* touch) {
		for (int i = 0; i < touchmaxcount; ++i) {
			if (touches[i] == touch) return i;
		}
		return -1;
	}
	
	int addTouch(void* touch) {
		for (int i = 0; i < touchmaxcount; ++i) {
			if (touches[i] == nullptr) {
				touches[i] = touch;
				return i;
			}
		}
		return -1;
	}
	
	int removeTouch(void* touch) {
		for (int i = 0; i < touchmaxcount; ++i) {
			if (touches[i] == touch) {
				touches[i] = nullptr;
				return i;
			}
		}
		return -1;
	}
}

@implementation GLView

+ (Class)layerClass {
    return [CAEAGLLayer class];
}

- (id)initWithFrame:(CGRect)frame {
	self = [super initWithFrame:(CGRect)frame];
	self.contentScaleFactor = [UIScreen mainScreen].scale;
	
	initTouches();
	
	CAEAGLLayer* eaglLayer = (CAEAGLLayer*)self.layer;
	
	eaglLayer.opaque = YES;
	eaglLayer.drawableProperties = [NSDictionary dictionaryWithObjectsAndKeys: [NSNumber numberWithBool:FALSE], kEAGLDrawablePropertyRetainedBacking, kEAGLColorFormatRGBA8, kEAGLDrawablePropertyColorFormat, nil];

	context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
	
	if (!context || ![EAGLContext setCurrentContext:context]) {
		//[self release];
		return nil;
	}
	
	glGenFramebuffersOES(1, &defaultFramebuffer);
	glGenRenderbuffersOES(1, &colorRenderbuffer);
	glBindFramebufferOES(GL_FRAMEBUFFER_OES, defaultFramebuffer);
	glBindRenderbufferOES(GL_RENDERBUFFER_OES, colorRenderbuffer);
	glFramebufferRenderbufferOES(GL_FRAMEBUFFER_OES, GL_COLOR_ATTACHMENT0_OES, GL_RENDERBUFFER_OES, colorRenderbuffer);
	
	glGenRenderbuffersOES(1, &depthRenderbuffer);
    glBindRenderbufferOES(GL_RENDERBUFFER_OES, depthRenderbuffer);
    glFramebufferRenderbufferOES(GL_FRAMEBUFFER_OES, GL_DEPTH_ATTACHMENT_OES, GL_RENDERBUFFER_OES, depthRenderbuffer);

    // Start acceletometer
	hasAccelerometer = false;

	motionManager = [[CMMotionManager alloc]init];
	if ([motionManager isAccelerometerAvailable]) {
		motionManager.accelerometerUpdateInterval = 0.033;
		[motionManager startAccelerometerUpdates];
		hasAccelerometer = true;
	}

	return self;
}

- (void)begin {
	[EAGLContext setCurrentContext:context];
    glBindFramebufferOES(GL_FRAMEBUFFER_OES, defaultFramebuffer);
    glViewport(0, 0, backingWidth, backingHeight);

    // Accelerometer updates
    if (hasAccelerometer) {

    	CMAcceleration acc = motionManager.accelerometerData.acceleration;

    	if (acc.x != lastAccelerometerX || acc.y != lastAccelerometerY || acc.z != lastAccelerometerZ) {
 			
    		Kore::Sensor::_changed(Kore::SensorAccelerometer, acc.x, acc.y, acc.z);

 			lastAccelerometerX = acc.x;
 			lastAccelerometerY = acc.y;
 			lastAccelerometerZ = acc.z;
 		}
    }
}

- (void)end {
	glBindRenderbufferOES(GL_RENDERBUFFER_OES, colorRenderbuffer);
	[context presentRenderbuffer:GL_RENDERBUFFER_OES]; //crash at end
}

- (void)layoutSubviews {
	glBindRenderbufferOES(GL_RENDERBUFFER_OES, colorRenderbuffer);
	[context renderbufferStorage:GL_RENDERBUFFER_OES fromDrawable:(CAEAGLLayer*)self.layer];
	glGetRenderbufferParameterivOES(GL_RENDERBUFFER_OES, GL_RENDERBUFFER_WIDTH_OES, &backingWidth);
	glGetRenderbufferParameterivOES(GL_RENDERBUFFER_OES, GL_RENDERBUFFER_HEIGHT_OES, &backingHeight);
	
	glBindRenderbufferOES(GL_RENDERBUFFER_OES, depthRenderbuffer);
	glRenderbufferStorageOES(GL_RENDERBUFFER_OES, GL_DEPTH_COMPONENT24_OES, backingWidth, backingHeight);
	
	if (glCheckFramebufferStatusOES(GL_FRAMEBUFFER_OES) != GL_FRAMEBUFFER_COMPLETE_OES) {
		NSLog(@"Failed to make complete framebuffer object %x", glCheckFramebufferStatusOES(GL_FRAMEBUFFER_OES));
	}
}

- (void)dealloc {
	if (defaultFramebuffer) {
		glDeleteFramebuffersOES(1, &defaultFramebuffer);
		defaultFramebuffer = 0;
	}
	
	if (colorRenderbuffer) {
		glDeleteRenderbuffersOES(1, &colorRenderbuffer);
		colorRenderbuffer = 0;
	}
	
	if ([EAGLContext currentContext] == context) [EAGLContext setCurrentContext:nil];
	
	//[context release];
	context = nil;
	
	//[super dealloc];
}
/*
- (void)touchesBegan:(NSSet*)touches withEvent:(UIEvent *)event {
	UITouch *touch = [touches anyObject];
	CGPoint point = [touch locationInView:self];
	Kore::Mouse::the()->_pressLeft(Kore::MouseEvent(point.x * self.contentScaleFactor,
													point.y * self.contentScaleFactor));
}

- (void)touchesMoved:(NSSet*)touches withEvent:(UIEvent *)event {
	UITouch *touch = [touches anyObject];
	CGPoint point = [touch locationInView:self];
	Kore::Mouse::the()->_move(Kore::MouseEvent(point.x * self.contentScaleFactor,
											   point.y * self.contentScaleFactor));
}

- (void)touchesEnded:(NSSet*)touches withEvent:(UIEvent *)event {
	UITouch *touch = [touches anyObject];
	CGPoint point = [touch locationInView:self];
	Kore::Mouse::the()->_releaseLeft(Kore::MouseEvent(point.x * self.contentScaleFactor,
													  point.y * self.contentScaleFactor));
}

- (void)touchesCancelled:(NSSet*)touches withEvent:(UIEvent *)event {
	UITouch *touch = [touches anyObject];
	CGPoint point = [touch locationInView:self];
	Kore::Mouse::the()->_releaseLeft(Kore::MouseEvent(point.x * self.contentScaleFactor,
													  point.y * self.contentScaleFactor));
}
*/
- (void)touchesBegan:(NSSet*)touches withEvent:(UIEvent*)event {
	for (UITouch* touch in touches) {
		int index = getTouchIndex((__bridge void*)touch);
		if (index == -1) index = addTouch((__bridge void*)touch);
		if (index >= 0) {
			CGPoint point = [touch locationInView: self];
			float x = point.x * self.contentScaleFactor;
			float y = point.y * self.contentScaleFactor;
			if (index == 0) {
				Kore::Mouse::the()->_press(0, x, y);
			}
			Kore::Surface::the()->_touchStart(index, x, y);
		}
	}
}

- (void)touchesMoved:(NSSet*)touches withEvent:(UIEvent*)event {
	for (UITouch* touch in touches) {
		int index = getTouchIndex((__bridge void*)touch);
		if (index >= 0) {
			CGPoint point = [touch locationInView: self];
			float x = point.x * self.contentScaleFactor;
			float y = point.y * self.contentScaleFactor;
			if (index == 0) {
				Kore::Mouse::the()->_move(x, y);
			}
			Kore::Surface::the()->_move(index, x, y);
		}
	}
}

- (void)touchesEnded:(NSSet*)touches withEvent:(UIEvent*)event {
	for (UITouch* touch in touches) {
		int index = removeTouch((__bridge void*)touch);
		if (index >= 0) {
			CGPoint point = [touch locationInView: self];
			float x = point.x * self.contentScaleFactor;
			float y = point.y * self.contentScaleFactor;
			if (index == 0) {
				Kore::Mouse::the()->_release(0, x, y);
			}
			Kore::Surface::the()->_touchEnd(index, x, y);
		}
	}
}

- (void)touchesCancelled:(NSSet*)touches withEvent:(UIEvent*)event {
	for (UITouch* touch in touches) {
		int index = removeTouch((__bridge void*)touch);
		if (index >= 0) {
			CGPoint point = [touch locationInView: self];
			float x = point.x * self.contentScaleFactor;
			float y = point.y * self.contentScaleFactor;
			if (index == 0) {
				Kore::Mouse::the()->_release(0, x, y);
			}
			Kore::Surface::the()->_touchEnd(index, x, y);
		}
	}
}

namespace {
	NSString* keyboardstring;
    UITextField* myTextField = nullptr;
	bool shiftDown = false;
}

- (void)showKeyboard {
	//[UIApplication sharedApplication].statusBarOrientation = UIInterfaceOrientationLandscapeRight;
	keyboardstring = [NSString string];
	if (myTextField == nullptr) {
		myTextField = [[UITextField alloc] initWithFrame:CGRectMake(0, 0, 0, 0)];
		[myTextField setDelegate:self];
		[myTextField setBorderStyle:UITextBorderStyleRoundedRect];
		[myTextField setBackgroundColor:[UIColor whiteColor]];
		[myTextField setTextColor:[UIColor blackColor]];
		[myTextField setClearButtonMode:UITextFieldViewModeAlways];
		[myTextField setFont:[UIFont fontWithName:@"Arial" size:18.0f]];
		[myTextField setPlaceholder:@"Tap here to edit"];
		//[myTextField setTextAlignment:UITextAlignmentCenter];
		[myTextField setReturnKeyType:UIReturnKeyDone];
	}
	[self addSubview:myTextField];
	[myTextField becomeFirstResponder];
	
}

- (void)hideKeyboard {
    [myTextField endEditing:YES];
    [myTextField removeFromSuperview];
}

- (void)textFieldDidEndEditing:(UITextField*)textField {
	//NSLog([textField text]);
	[textField endEditing:YES];
	[textField removeFromSuperview];
}

- (BOOL)textFieldShouldReturn:(UITextField*)texField {
	// end editing
	[texField resignFirstResponder];
	return YES;
}

- (BOOL)textField:(UITextField*)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString*)string {
	if ([string length] == 1) {
		unichar ch = [string characterAtIndex: [string length] - 1];
		if (ch >= L'a' && ch <= L'z') {
			if (shiftDown) {
				Kore::Keyboard::the()->_keyup(Kore::Key_Shift, 0);
				shiftDown = false;
			}
			Kore::Keyboard::the()->_keydown((Kore::KeyCode)(ch + L'A' - L'a'), ch);
		}
		else {
			if (!shiftDown) {
				Kore::Keyboard::the()->_keydown(Kore::Key_Shift, 0);
				shiftDown = true;
			}
			Kore::Keyboard::the()->_keydown((Kore::KeyCode)ch, ch);
		}
	}
	else if ([string length] == 0 && range.length == 1) {
		Kore::Keyboard::the()->_keydown(Kore::Key_Backspace, 0);
		return NO;
	}
	return YES;
}

@end
