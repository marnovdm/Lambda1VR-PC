#!/usr/bin/env python3
"""Add Lambda1VR-PC to the Steam library as non-Steam VR shortcuts ("Half-Life VR", "Blue Shift VR",
"Opposing Force VR", "Counter-Strike VR" with cs16-client), one per installed game folder, with badge artwork made
from each game's own Steam art.

Steam must be closed: it rewrites shortcuts.vdf on exit. shortcuts.vdf is backed up next to itself first.
Running it again updates the existing shortcuts instead of adding duplicates.

Usage: steam-shortcuts.py [--root ~/Games/lambda1vr-pc] [--launcher ~/.local/bin/lambda1vr-pc]
                          [--steam ~/.local/share/Steam] [--no-art] [--art-only] [--dry-run]
Artwork needs Pillow (python-pillow); without it the shortcuts are added without art.
"""
import argparse, glob, os, shutil, struct, subprocess, sys, time, zlib

GAMES = [  # folder, shortcut name, launch options, Steam app whose art is used, icon accent colour
	( 'valve', 'Half-Life VR', '', '70', 'ff8c00' ),
	( 'bshift', 'Blue Shift VR', '-game bshift', '130', '3c8ce6' ),
	( 'gearbox', 'Opposing Force VR', '-game gearbox', '50', '5ac83c' ),
	( 'cstrike', 'Counter-Strike VR', '-game cstrike', '10', 'e6b43c' ),  # needs the cs16-client install
]


# --- Steam binary VDF (shortcuts.vdf): 0x00 map, 0x01 string, 0x02 int32, 0x03 float, 0x07 uint64, 0x08 end ---
def vdf_load( data ):
	pos = 0

	def cstring():
		nonlocal pos
		end = data.index( b'\0', pos )
		s = data[pos:end].decode( 'utf-8', 'replace' )
		pos = end + 1
		return s

	def mapping():
		nonlocal pos
		out = {}
		while True:
			kind = data[pos]
			pos += 1
			if kind == 0x08:
				return out
			key = cstring()
			if kind == 0x00:
				out[key] = mapping()
			elif kind == 0x01:
				out[key] = cstring()
			elif kind == 0x02:
				out[key] = struct.unpack_from( '<i', data, pos )[0]; pos += 4
			elif kind == 0x03:
				out[key] = struct.unpack_from( '<f', data, pos )[0]; pos += 4
			elif kind == 0x07:
				out[key] = ( 'u64', struct.unpack_from( '<Q', data, pos )[0] ); pos += 8
			else:
				raise ValueError( f'unknown VDF type {kind:#x} at {pos - 1}' )

	return mapping()


def vdf_dump( obj ):
	out = bytearray()
	for key, value in obj.items():
		k = key.encode() + b'\0'
		if isinstance( value, dict ):
			out += b'\x00' + k + vdf_dump( value )
		elif isinstance( value, str ):
			out += b'\x01' + k + value.encode() + b'\0'
		elif isinstance( value, tuple ):
			out += b'\x07' + k + struct.pack( '<Q', value[1] )
		elif isinstance( value, float ):
			out += b'\x03' + k + struct.pack( '<f', value )
		else:
			out += b'\x02' + k + struct.pack( '<i', value )
	return bytes( out + b'\x08' )


def shortcut_appid( exe, name ):
	"""Steam's id for a non-Steam shortcut: CRC32 of exe + name with the top bit set (unsigned 32-bit)."""
	return zlib.crc32(( exe + name ).encode()) | 0x80000000


def steam_user_config( steam ):
	"""config folder of the Steam account used most recently on this machine."""
	dirs = [d for d in glob.glob( os.path.join( steam, 'userdata', '*', 'config' )) if os.path.basename( os.path.dirname( d )) != '0']
	if not dirs:
		sys.exit( f'no Steam user found under {steam}/userdata - start Steam and log in once' )
	return max( dirs, key=lambda d: os.path.getmtime( os.path.join( d, 'localconfig.vdf' )) if os.path.exists( os.path.join( d, 'localconfig.vdf' )) else 0 )


# --- artwork: the game's own library art with an orange "VR" tag in Half-Life HUD style ---
ORANGE = ( 255, 140, 0 )


def make_art( steam, grid, appid, source_app, icon_path, accent, dry_run ):
	from PIL import Image, ImageDraw, ImageFont

	src = os.path.join( steam, 'appcache', 'librarycache', source_app )
	font_path = subprocess.run( [ 'fc-match', '-f', '%{file}', 'DejaVu Sans:bold' ], capture_output=True, text=True ).stdout \
		if shutil.which( 'fc-match' ) else ''

	def font( size ):
		return ImageFont.truetype( font_path, size ) if font_path else ImageFont.load_default( size )

	def badge( text, height ):
		f = font( int( height * 0.72 ))
		box = f.getbbox( text )
		pad = int( height * 0.32 )
		width = box[2] - box[0] + 2 * pad
		img = Image.new( 'RGBA', ( width, height ), ( 0, 0, 0, 0 ))
		draw = ImageDraw.Draw( img )
		draw.rounded_rectangle(( 0, 0, width - 1, height - 1 ), radius=int( height * 0.22 ), fill=( 18, 18, 18, 235 ),
			outline=ORANGE + ( 255, ), width=max( 2, height // 16 ))
		draw.text((( width - ( box[2] - box[0] )) / 2 - box[0], ( height - ( box[3] - box[1] )) / 2 - box[1] ), text,
			font=f, fill=ORANGE + ( 255, ))
		return img

	def stamp( name, size, rel_height, out, bottom=False ):
		img = Image.open( os.path.join( src, name )).convert( 'RGB' )
		scale = max( size[0] / img.width, size[1] / img.height )
		img = img.resize(( round( img.width * scale ), round( img.height * scale )), Image.LANCZOS )
		left, top = ( img.width - size[0] ) // 2, ( img.height - size[1] ) // 2
		img = img.crop(( left, top, left + size[0], top + size[1] ))
		tag = badge( 'VR', int( size[1] * rel_height ))
		margin = int( size[1] * rel_height * 0.35 )
		img.paste( tag, ( size[0] - tag.width - margin, size[1] - tag.height - margin if bottom else margin ), tag )
		img.save( out, quality=92 )

	def logo( out ):
		img = Image.open( os.path.join( src, 'logo.png' )).convert( 'RGBA' )
		img = img.crop( img.getbbox())
		tag = badge( 'VR', img.height )
		gap = img.height // 3
		canvas = Image.new( 'RGBA', ( img.width + gap + tag.width, img.height ), ( 0, 0, 0, 0 ))
		canvas.paste( img, ( 0, 0 ), img )
		canvas.paste( tag, ( img.width + gap, 0 ), tag )
		canvas.save( out )

	def icon( out ):
		size = 256
		img = Image.new( 'RGBA', ( size, size ), ( 0, 0, 0, 0 ))
		draw = ImageDraw.Draw( img )
		draw.rounded_rectangle(( 0, 0, size - 1, size - 1 ), radius=40, fill=( 24, 24, 24, 255 ))
		f = font( 190 )
		box = f.getbbox( 'λ' )
		colour = tuple( int( accent[i:i + 2], 16 ) for i in ( 0, 2, 4 ))
		draw.text((( size - ( box[2] - box[0] )) / 2 - box[0], ( size - ( box[3] - box[1] )) / 2 - box[1] - 18 ), 'λ',
			font=f, fill=colour + ( 255, ))
		tag = badge( 'VR', 74 )
		img.paste( tag, ( size - tag.width - 10, size - tag.height - 10 ), tag )
		img.save( out )

	outputs = [
		( f'{appid}p.jpg', lambda o: stamp( 'library_600x900.jpg', ( 600, 900 ), 0.085, o, bottom=True )),
		( f'{appid}.jpg', lambda o: stamp( 'header.jpg', ( 920, 430 ), 0.17, o )),
		( f'{appid}_hero.jpg', lambda o: stamp( 'library_hero.jpg', ( 1920, 620 ), 0.14, o )),
		( f'{appid}_logo.png', logo ),
	]
	if dry_run:
		print( f'  would write artwork for {appid} to {grid} and {icon_path}' )
		return
	os.makedirs( grid, exist_ok=True )
	backup = os.path.join( grid, time.strftime( '.backup-%Y%m%d-%H%M%S' ))
	for name, make in outputs:
		path = os.path.join( grid, name )
		try:
			if os.path.exists( path ):
				os.makedirs( backup, exist_ok=True )
				shutil.move( path, os.path.join( backup, name ))
			make( path )
		except FileNotFoundError as e:
			print( f'  skipped {name}: Steam has no cached art for app {source_app} ({e.filename})' )
	icon( icon_path )


def main():
	ap = argparse.ArgumentParser( description=__doc__.split( '\n' )[0] )
	ap.add_argument( '--root', default='~/Games/lambda1vr-pc' )
	ap.add_argument( '--launcher', default='~/.local/bin/lambda1vr-pc' )
	ap.add_argument( '--steam', default='~/.local/share/Steam' )
	ap.add_argument( '--no-art', action='store_true' )
	ap.add_argument( '--art-only', action='store_true', help='only (re)make the artwork; Steam may be running' )
	ap.add_argument( '--dry-run', action='store_true' )
	args = ap.parse_args()
	root, steam = os.path.expanduser( args.root ), os.path.expanduser( args.steam )
	exe = '"' + os.path.expanduser( args.launcher ) + '"'
	config = steam_user_config( steam )
	games = [g for g in GAMES if os.path.isdir( os.path.join( root, g[0] ))]
	if not games:
		sys.exit( f'no game folders in {root}' )

	art = not args.no_art
	if art:
		try:
			import PIL  # noqa: F401
		except ImportError:
			print( 'Pillow (python-pillow) not installed: adding the shortcuts without artwork' )
			art = False

	if not args.art_only:
		if not args.dry_run and subprocess.run( [ 'pgrep', '-x', 'steam' ], capture_output=True ).returncode == 0:
			sys.exit( 'Steam is running - close it first (it rewrites shortcuts.vdf on exit), or use --art-only' )
		path = os.path.join( config, 'shortcuts.vdf' )
		data = vdf_load( open( path, 'rb' ).read()) if os.path.exists( path ) else { 'shortcuts': {} }
		entries = data.setdefault( 'shortcuts', {} )
		for folder, name, options, _, _ in games:
			appid = shortcut_appid( exe, name )
			entry = next(( e for e in entries.values() if e.get( 'AppName' ) == name ), None )
			if entry is None:
				entry = {
					'appid': appid - ( 1 << 32 ),  # stored as signed int32
					'AppName': name, 'Exe': exe, 'StartDir': '"' + root + '/"', 'icon': '', 'ShortcutPath': '',
					'LaunchOptions': '', 'IsHidden': 0, 'AllowDesktopConfig': 1, 'AllowOverlay': 1,
					'OpenVR': 1, 'Devkit': 0, 'DevkitGameID': '', 'DevkitOverrideAppID': 0, 'LastPlayTime': 0,
					'FlatpakAppID': '', 'sortas': '', 'tags': {},
				}
				entries[str( len( entries ))] = entry
				print( f'adding "{name}" (appid {appid})' )
			else:
				print( f'updating "{name}"' )
			entry.update({ 'Exe': exe, 'StartDir': '"' + root + '/"', 'LaunchOptions': options, 'OpenVR': 1,
				'icon': os.path.join( root, folder, 'icon-vr.png' ) if art else entry.get( 'icon', '' ) })
		if args.dry_run:
			print( f'dry run: {path} not written' )
		else:
			if os.path.exists( path ):
				shutil.copy2( path, path + time.strftime( '.bak-%Y%m%d-%H%M%S' ))
			with open( path, 'wb' ) as f:
				f.write( vdf_dump( data ))
			print( 'written', path )

	if art:
		for folder, name, _, source_app, accent in games:
			print( f'artwork for "{name}"' )
			make_art( steam, os.path.join( config, 'grid' ), shortcut_appid( exe, name ), source_app,
				os.path.join( root, folder, 'icon-vr.png' ), accent, args.dry_run )
	print( 'Start Steam again to see the shortcuts (under Non-Steam / VR in the library).' )


if __name__ == '__main__':
	main()
