# Customisable Sleep Screen Patch

A KOReader patch that displays reading statistics and book information on your sleep screen with extensive customisation options and the ability to save/load preset configurations.

<p>
<img width="1920" height="1080" alt="Full Set" src="https://github.com/user-attachments/assets/c0b32289-7ac6-43f9-988a-1e31a32b362d" />
</p>

## Features:

- Book progress, chapter progress, daily reading/goal progress, battery stats.
- Random book highlights (with location), or custom messages.
- Save your own configurations, 8 built-in presets included.
- Light/dark/monochrome modes (suitable for non-colour e-readers).
- Background: book cover (with optional overlay), images from folder, solid colour or transparent.
- Coloured progress bars for percentage stats.
- Dynamic icons for sections, with several icon-sets included.
- Reorder sections, adjust section spacing, show/hide elements.
- Customise layout, position, opacity, borders, font face/size, text alignment.
- Option to clean chapter title (remove prefixes like "Chapter 5:", leaving chapter names only).
- Option to show in file manager (displays last book's data).
- Quick access via taps and gestures shortcuts.

## Tested On:

- KOReader 2025.10 (Ghost) with Kobo Libra Colour & Kindle PW 10th Gen.

## Notes:

- Adding custom icon sets: Create folders in 'customisable-sleep-screen-iconsets/' using the same naming structure as existing icon sets. Supports PNG, JPG, and SVG formats. SVG files will be automatically recoloured when the recolour option is enabled in settings.
- Adding custom font faces: Add .ttf/.otf files to koreader/fonts/.
- Quick access shortcuts: Add preset switching and settings access to your KOReader taps & gestures. The options can be found in the taps & gestures general category.
- Better visibility: Enable "Postpone screen update after wakeup" in settings to show sleep screen with front-light when waking up the device.

## Installation:

1. Download the latest [files](https://github.com/pxlflux/koreader-patches/archive/refs/heads/main.zip).
2. Copy to your KOReader in the following locations:
	- '2-customisable-sleep-screen.lua'				→ 'koreader/patches/'
	- 'customisable-sleep-screen-iconsets/' folder	→ 'koreader/icons/'
	- 'customisable-sleep-screen-fonts/' folder		→ 'koreader/fonts/'
3. Restart KOReader.
4. Enable the patch:
	'Settings → Screen → Sleep screen → Wallpaper → Customisable sleep screen'
5. Tap the Default preset once after installation to refresh and display the custom font:
   	'Settings → Screen → Sleep screen → Wallpaper → Customisable sleep screen settings → Presets → Default'

## Fonts, Icons & Attribution

- Fonts are from Google Fonts, used under the [SIL Open Font License](https://scripts.sil.org/OFL). OFL license files are included in ‘customisable-sleep-screen-fonts/’ for each font.
- Icons are from the following sources; some have been modified from the originals.
	- Default icons: [Solar](https://www.figma.com/community/file/1166831539721848736) - licensed under CC BY 4.0.
	- Pixel icons: [Pixel](https://www.figma.com/community/file/1196864707579677521) - licensed under CC BY 4.0.
	- Sketch icons: [Doodle](https://www.figma.com/community/file/1019353050314527791) - licensed under CC BY 4.0.
	- Silhouette icons: [MaterialDesign](https://github.com/Templarian/MaterialDesign) - licensed under the Apache 2.0 License.
	- Comic icons: Custom icon set created for this project.

