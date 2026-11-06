import AppKit

// make-icon.swift - render resources/icon.icns source images:
// white cup.and.saucer.fill on a rounded espresso-brown squircle.
//
// usage: swift make-icon.swift <output.iconset-dir>

let sizes: [(String, Int)] = [
	("16x16", 16), ("16x16@2x", 32),
	("32x32", 32), ("32x32@2x", 64),
	("128x128", 128), ("128x128@2x", 256),
	("256x256", 256), ("256x256@2x", 512),
	("512x512", 512), ("512x512@2x", 1024),
]

guard CommandLine.arguments.count > 1 else {
	fputs("usage: swift make-icon.swift <output.iconset-dir>\n", stderr)
	exit(2)
}
let outDir = CommandLine.arguments[1]

for (label, px) in sizes {
	guard let rep = NSBitmapImageRep(
		bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
		bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
		colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
	), let ctx = NSGraphicsContext(bitmapImageRep: rep) else {
		fputs("error: cannot create bitmap for \(px)px\n", stderr)
		exit(1)
	}

	NSGraphicsContext.saveGraphicsState()
	NSGraphicsContext.current = ctx

	let side = CGFloat(px)
	let rect = NSRect(x: 0, y: 0, width: side, height: side)

	// background squircle - espresso brown
	NSColor(calibratedRed: 0.23, green: 0.14, blue: 0.09, alpha: 1).setFill()
	NSBezierPath(roundedRect: rect, xRadius: side * 0.22, yRadius: side * 0.22).fill()

	// white cup glyph, tinted via destinationIn
	if let sym = NSImage(systemSymbolName: "cup.and.saucer.fill", accessibilityDescription: nil),
		let configured = sym.withSymbolConfiguration(
			NSImage.SymbolConfiguration(pointSize: side * 0.58, weight: .medium))
	{
		let tinted = NSImage(size: configured.size)
		tinted.lockFocus()
		NSColor.white.setFill()
		NSRect(origin: .zero, size: configured.size).fill()
		configured.draw(in: NSRect(origin: .zero, size: configured.size), from: .zero, operation: .destinationIn, fraction: 1)
		tinted.unlockFocus()
		let w = configured.size.width
		let h = configured.size.height
		tinted.draw(
			in: NSRect(x: (side - w) / 2, y: (side - h) / 2, width: w, height: h),
			from: .zero, operation: .sourceOver, fraction: 1)
	}

	NSGraphicsContext.restoreGraphicsState()

	guard let data = rep.representation(using: .png, properties: [:]) else {
		fputs("error: cannot encode png for \(px)px\n", stderr)
		exit(1)
	}
	do {
		try data.write(to: URL(fileURLWithPath: "\(outDir)/icon_\(label).png"))
	} catch {
		fputs("error: \(error.localizedDescription)\n", stderr)
		exit(1)
	}
}
print("wrote iconset to \(outDir)")
