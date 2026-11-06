extends RefCounted
## Bundled vector icons for interface marks the bundled fonts do not carry (lock, pause, play, check, star).
## Each is a small SVG rasterised at runtime at the size asked for, so the game never depends on a font installed
## on the player's machine. Drawn white: tint them with a Button's icon colours or a TextureRect's modulate.

const SVG := {
	"lock": '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24"><path d="M7.5 10.5V7.5a4.5 4.5 0 0 1 9 0v3" fill="none" stroke="#ffffff" stroke-width="2.4" stroke-linecap="round"/><rect x="4.5" y="10.5" width="15" height="10.5" rx="2" fill="#ffffff"/></svg>',
	"pause": '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24"><rect x="5.5" y="4" width="4.5" height="16" rx="1" fill="#ffffff"/><rect x="14" y="4" width="4.5" height="16" rx="1" fill="#ffffff"/></svg>',
	"play": '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24"><path d="M7 4.5v15l12.5-7.5z" fill="#ffffff"/></svg>',
	"check": '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24"><path d="M4.5 12.5l5 5 10-11" fill="none" stroke="#ffffff" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"/></svg>',
	"bell": '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24"><path d="M12 3.5a6 6 0 0 0-6 6v4.5l-2 3h16l-2-3V9.5a6 6 0 0 0-6-6z" fill="#ffffff"/><path d="M9.5 19a2.5 2.5 0 0 0 5 0z" fill="#ffffff"/></svg>',
	"chart": '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24"><rect x="4" y="12" width="4" height="8" rx="1" fill="#ffffff"/><rect x="10" y="6" width="4" height="14" rx="1" fill="#ffffff"/><rect x="16" y="9" width="4" height="11" rx="1" fill="#ffffff"/></svg>',
	"menu": '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24"><rect x="4" y="5.5" width="16" height="2.4" rx="1.2" fill="#ffffff"/><rect x="4" y="10.8" width="16" height="2.4" rx="1.2" fill="#ffffff"/><rect x="4" y="16.1" width="16" height="2.4" rx="1.2" fill="#ffffff"/></svg>',
	"flag": '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24"><rect x="5" y="3" width="2.2" height="18" rx="1" fill="#ffffff"/><path d="M7.2 4h11l-2.5 4 2.5 4h-11z" fill="#ffffff"/></svg>',
	"star": '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24"><path d="M12 3l2.7 5.6 6.1.8-4.5 4.2 1.1 6.1L12 16.8 6.6 19.7l1.1-6.1-4.5-4.2 6.1-.8z" fill="#ffffff"/></svg>',
}

static var _cache := {}


static func texture(name: String, px := 16) -> Texture2D:   # the icon as a px-by-px texture (cached)
	var key := "%s@%d" % [name, px]
	if _cache.has(key): return _cache[key]
	var img := Image.new()
	if not SVG.has(name) or img.load_svg_from_string(str(SVG[name]), float(px) / 24.0) != OK: return null
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex
