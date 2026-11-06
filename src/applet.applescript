use AppleScript version "2.5"
use framework "Foundation"
use framework "AppKit"
use scripting additions

-- doppio - menu bar controller for caffeinate.
-- Thin UI layer: all session logic lives in the embedded shell core.
-- The applet derives all names from its own bundle at runtime, so the
-- project can be renamed via ./install.sh --name

property statusItem : missing value
property statusMenu : missing value
property statusLabel : missing value
property stopItem : missing value
property loginToggle : missing value
property appName : missing value
property corePath : missing value
property sessionOn : false
property menuOpen : false
property loginItemState : false

-- raw values from <AppKit/NSEvent.h>
property NSEventTypeRightMouseUp : 4
property NSEventMaskLeftMouseUp : 4
property NSEventMaskRightMouseUp : 16

on run
	set appName to my appDisplayName()
	set cliName to (current application's NSString's stringWithString:appName)'s lowercaseString() as text
	set corePath to (POSIX path of (path to me)) & "Contents/Resources/" & cliName
	set loginItemState to my isLoginItem()

	set statusItem to current application's NSStatusBar's systemStatusBar()'s statusItemWithLength:(current application's NSVariableStatusItemLength)

	set statusMenu to current application's NSMenu's alloc()'s initWithTitle:appName

	set statusLabel to my newItem(appName, missing value)
	statusLabel's setEnabled:false
	statusMenu's addItem:statusLabel
	statusMenu's addItem:(current application's NSMenuItem's separatorItem())

	set startMenu to current application's NSMenu's alloc()'s initWithTitle:"Start"
	startMenu's addItem:(my newItem("Indefinitely", "startIndefinite:"))
	startMenu's addItem:(current application's NSMenuItem's separatorItem())
	startMenu's addItem:(my newTimedItem("15 minutes", 900))
	startMenu's addItem:(my newTimedItem("30 minutes", 1800))
	startMenu's addItem:(my newTimedItem("1 hour", 3600))
	startMenu's addItem:(my newTimedItem("2 hours", 7200))
	startMenu's addItem:(my newTimedItem("4 hours", 14400))
	set startItem to my newItem("Start Session", missing value)
	startItem's setSubmenu:startMenu
	statusMenu's addItem:startItem

	set stopItem to my newItem("Stop Session", "stopSession:")
	statusMenu's addItem:stopItem
	statusMenu's addItem:(current application's NSMenuItem's separatorItem())

	set loginToggle to my newItem("Launch at Login", "toggleLoginItem:")
	statusMenu's addItem:loginToggle
	statusMenu's addItem:(current application's NSMenuItem's separatorItem())

	set quitItem to my newItem("Quit " & appName, "quitApp:")
	quitItem's setKeyEquivalent:"q"
	statusMenu's addItem:quitItem

	statusMenu's setDelegate:me

	-- the menu is attached only transiently, so the button can distinguish left-click (menu) from control/right-click (toggle)
	set btn to statusItem's button()
	btn's setAction:"statusItemClicked:"
	btn's setTarget:me
	btn's sendActionOn:(NSEventMaskLeftMouseUp + NSEventMaskRightMouseUp)

	set t to current application's NSTimer's timerWithTimeInterval:1 target:me selector:"tick:" userInfo:(missing value) repeats:true
	current application's NSRunLoop's currentRunLoop()'s addTimer:t forMode:(current application's NSRunLoopCommonModes)

	my refreshUI()
end run

-- MARK: - naming

on appDisplayName()
	try
		set bundleName to (current application's NSBundle's mainBundle()'s objectForInfoDictionaryKey:"CFBundleName") as text
		if bundleName is not "" then return bundleName
	end try
	-- fallback: derive from the bundle path (e.g. /Applications/Doppio.app)
	set p to POSIX path of (path to me)
	if p ends with "/" then set p to text 1 thru -2 of p
	set AppleScript's text item delimiters to "/"
	set base to last text item of p
	set AppleScript's text item delimiters to ""
	if base ends with ".app" then set base to text 1 thru -5 of base
	return base
end appDisplayName

-- MARK: - menu construction

on newItem(theTitle, theAction)
	set mi to current application's NSMenuItem's alloc()'s initWithTitle:theTitle action:theAction keyEquivalent:""
	mi's setTarget:me
	return mi
end newItem

on newTimedItem(theTitle, secs)
	set mi to my newItem(theTitle, "startTimed:")
	mi's setRepresentedObject:(current application's NSNumber's numberWithInteger:secs)
	return mi
end newTimedItem

-- MARK: - status item clicks + menu delegate

on statusItemClicked_(sender)
	set evt to current application's NSApp's currentEvent()
	if evt's type() is NSEventTypeRightMouseUp then
		-- control-click / right-click: quick toggle
		my quickToggle()
	else
		-- left-click: menu
		statusItem's setMenu:statusMenu
		statusItem's button()'s performClick:(missing value)
	end if
end statusItemClicked_

on menuWillOpen_(menu)
	set menuOpen to true
	my refreshUI()
end menuWillOpen_

on menuDidClose_(menu)
	set menuOpen to false
	statusItem's setMenu:(missing value)
end menuDidClose_

-- 1 Hz: live-update the countdown while the menu is being viewed
on tick_(timer)
	if menuOpen and sessionOn then my refreshUI()
end tick_

-- MARK: - actions

on quickToggle()
	if sessionOn then
		my core("off")
	else
		-- optional override: `defaults write <bundle-id> quickStart 30m`
		set qs to (current application's NSUserDefaults's standardUserDefaults()'s stringForKey:"quickStart")
		if qs is missing value then
			my core("on")
		else
			try
				my core("on " & (qs as text))
			on error
				my core("on")
			end try
		end if
	end if
	my refreshUI()
end quickToggle

on startIndefinite_(sender)
	my core("on")
	my refreshUI()
end startIndefinite_

on startTimed_(sender)
	set secs to (sender's representedObject()'s integerValue()) as integer
	my core("on " & secs & "s")
	my refreshUI()
end startTimed_

on stopSession_(sender)
	my core("off")
	my refreshUI()
end stopSession_

on toggleLoginItem_(sender)
	tell application "System Events"
		if (exists login item appName) then
			delete login item appName
		else
			make new login item at end of login items with properties {path:(POSIX path of (path to me)), name:appName, hidden:false}
		end if
	end tell
	set loginItemState to my isLoginItem()
	loginToggle's setState:(loginItemState as integer)
end toggleLoginItem_

on quitApp_(sender)
	current application's NSApp's terminate:me
end quitApp_

-- MARK: - state + ui

on core(args)
	do shell script quoted form of corePath & " " & args
end core

on coreStatus()
	try
		return my core("status")
	on error
		return "off"
	end try
end coreStatus

on refreshUI()
	set statusText to my coreStatus()
	set parts to words of statusText
	if (count of parts) > 0 and item 1 of parts is "on" then
		set sessionOn to true
		if (count of parts) > 1 and item 2 of parts is not "indefinite" then
			set secs to (item 2 of parts) as integer
			my setIcon(true, my fmtClock(secs))
			statusLabel's setTitle:("On - " & my fmtLong(secs) & " remaining")
		else
			my setIcon(true, "∞")
			statusLabel's setTitle:"On - indefinitely"
		end if
		stopItem's setEnabled:true
	else
		set sessionOn to false
		my setIcon(false, "")
		statusLabel's setTitle:"Off"
		stopItem's setEnabled:false
	end if
	loginToggle's setState:(loginItemState as integer)
end refreshUI

on setIcon(isOn, badgeText)
	set sym to "cup.and.saucer"
	if isOn then set sym to "cup.and.saucer.fill"
	set img to current application's NSImage's imageWithSystemSymbolName:sym accessibilityDescription:appName
	if img is missing value then
		statusItem's button()'s setImage:(missing value)
		if badgeText is "" then
			statusItem's button()'s setTitle:"☕"
		else
			statusItem's button()'s setTitle:("☕ " & badgeText)
		end if
	else
		img's setTemplate:true
		statusItem's button()'s setImage:img
		statusItem's button()'s setTitle:badgeText
	end if
end setIcon

-- "H:MM" clock for the menu bar title (e.g. 1:05, 0:42)
on fmtClock(secs)
	set h to secs div 3600
	set m to (secs mod 3600) div 60
	return (h as text) & ":" & text -2 thru -1 of ("0" & m)
end fmtClock

-- extended form for the menu label (e.g. "1h 5m 3s", "42s")
on fmtLong(secs)
	set h to secs div 3600
	set m to (secs mod 3600) div 60
	set s to secs mod 60
	set out to ""
	if h > 0 then set out to out & h & "h "
	if m > 0 or h > 0 then set out to out & m & "m "
	return out & s & "s"
end fmtLong

on isLoginItem()
	try
		tell application "System Events"
			return (exists login item appName)
		end tell
	on error
		return false
	end try
end isLoginItem

-- MARK: - lifecycle

on idle
	my refreshUI()
	if sessionOn then
		return 2
	else
		return 30
	end if
end idle

on quit
	try
		my core("off")
	end try
	continue quit
end quit
