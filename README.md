# Customisable Sleep Screen

A KOReader plugin that displays reading statistics and book information on your sleep screen with extensive customisation options and the ability to save/load preset configurations.

Originally released as a patch, this project has now been rebuilt as a KOReader plugin.

<p>
<img width="1920" height="1080" alt="GHMain" src="https://github.com/user-attachments/assets/600a8f43-06e3-4e66-86df-a70fe0b28473" />
</p>

## Features:

- Book progress, chapter progress, daily reading/goal progress, battery stats
- Random book highlights (with location), or custom messages
- Save and load your own configurations, with 10 built-in presets included
- Light/dark/monochrome modes (suitable for non-colour e-readers)
- Background options: book cover (with optional overlay), images from folder, solid colour or transparent
- Coloured progress bars for percentage stats with option to place inline with text
- Customise info-box background and text colour
- Dynamic icons for sections, with 7 icon sets included
- Reorder sections, adjust section spacing, show/hide elements
- Customise layout, padding, position, opacity, borders, font face/size, text alignment, corner rounding
- Option to clean chapter title (remove prefixes like "Chapter 5:", leaving chapter names only)
- Option to show in file manager (displays last book's data)
- Choose whether daily stats apply to all books or the current book only
- Quick access through taps and gestures shortcuts
- Sleep screen orientation lock
- Export sleep screen as image for use with android screen saver.
- Language support for 13 languages: `de`, `es`, `fr`, `it`, `ja`, `ko`, `nl`, `pl`, `pt_BR`, `ru`, `tr`, `vi`, `zh_CN`

## Compatibility:

The following list assumes KOReader’s latest build (2026.03 Snowflake) is installed and summarises the compatibility to the best of my knowledge.

| Device                 | Status          | Notes                                                             |
| ---------------------- | --------------- | ----------------------------------------------------------------- |
| Kobo                   | ✅ Works         | Most supported platform. Tested on Kobo Libra Colour              |
| Kindle                 | ✅ Works         | Tested on Kindle PW 10^(th) Gen                                   |
| Android / Desktop      | 🟠 Partial support | KOReader’s Sleep Screen feature is unavailable on these platforms however an image can be exported to use with the devices screensaver. |
| Cervantes / reMarkable | 🟡 Unverified   | Untested on these devices.                                        |
| PocketBook             | ❌ Not supported | Device firmware overrides KOReader’s Sleep Screen                 |

## Notes:

- **Custom icon sets:** Add your own icon sets to the plugin’s icon directory using the same folder and naming structure as existing icon sets. PNG, JPG, and SVG formats are supported. SVG files will be recoloured when the recolour option is enabled in settings
- **Custom fonts:** Add `.ttf` or `.otf` files to the KOReader fonts directory if you want to use your own fonts
- **Quick access shortcuts:** Add preset menu access, preset cycling and settings access through KOReader’s taps & gestures. The options can be found in the taps & gestures general category
- **Better visibility on wake:** Enable "Postpone screen update after wakeup" in settings to show sleep screen with front-light when waking up the device

## Installation:

1. Download `customisablesleepscreen_v2.0.0.zip` from the latest [release](https://github.com/pxlflux/customisablesleepscreen.koplugin/releases)
2. Extract the zip and place the `customisablesleepscreen.koplugin` folder into your KOReader `/plugins` folder
3. Restart KOReader
4. Enable the plugin in  'Settings → Screen → Customisable Sleep Screen'

## Language Support:

1. A .pot template file is included in the `l10n` folder. You can use this to create a translation for any language.
2. Make a copy of the .pot file and rename as a .po with your language locale (e.g. es.po, fr.po, it.po etc.).
3. Open the file with a text editor or a dedicated program like [Poedit](https://poedit.net/) and fill each msgstr with your translation. For ease, I have split the main display strings (those shown on the sleep screen) into their own section at the top of the file if that's all that's important to you for translation.
4. Save the .po file in the `l10n/` folder and restart KOReader to see it available as an option in the language menu.

## Fonts, Icons, Wallpapers & Attribution

- Fonts are from Google Fonts, used under the [SIL Open Font License](https://scripts.sil.org/OFL). OFL license files are included in ‘customisable-sleep-screen-fonts/’ for each font
- Icons are from the following sources (some have been modified from the originals):
	- Default icons: [Solar](https://www.figma.com/community/file/1166831539721848736) - licensed under CC BY 4.0
	- Pixel icons: [Pixel](https://www.figma.com/community/file/1196864707579677521) - licensed under CC BY 4.0
	- Sketch icons: [Doodle](https://www.figma.com/community/file/1019353050314527791) - licensed under CC BY 4.0
	- Silhouette icons: [MaterialDesign](https://github.com/Templarian/MaterialDesign) - licensed under the Apache 2.0 License
	- Fluent icons: [Fluent Emoji](https://github.com/microsoft/fluentui-emoji) - licensed under the MIT License
	- Circle icons: [Tela Circle](https://github.com/vinceliuice/Tela-circle-icon-theme) - licensed under the GNU GPL v3.0
	- Comic icons: Custom icon set created for this project
- Wallpaper sets are from two sources, and have been cropped to suit e-reader dimensions:
	- [Nordic-wallpapers](https://github.com/linuxdotexe/nordic-wallpapers) was used for the Nord wallpaper set, licensed under the MIT License
	- [Walls-catppuccin-mocha](https://github.com/orangci/walls-catppuccin-mocha) was used for the Catppuccin wallpaper set. No license is specified. The repository appears to collect third-party artwork from various sources, so original rights likely remain with the respective artists
