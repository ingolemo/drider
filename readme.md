![Drider 3ds epub reader](banner.png)

# Drider

Drider is a epub reader for the Nintendo 3ds. In order to run it you
will need a way to run homebrew applications on your 3ds. It is written
in Lua using Rinnegatamante's [Lua Player Plus 3ds].

[lua player plus 3ds]: https://github.com/Rinnegatamante/lpp-3ds "lpp-3ds"

Drider has a few limitations:

- It does not support css or any kind of inline styling, such as &lt;b&gt;
  or &lt;i&gt; tags.
- It doesn't handle non-ascii text well. If you're reading a utf-8
  encoded book then it tries to translate some of the most common
  symbols to ascii equivalents, but the conversion is incomplete so
  mojibake is common.
- Text rendering on the 3ds is not very good so you will see plenty of
  bad kerning.
- Drider can crash with books that contain large images. If the images
  are not important then consider disabling them (x button at the book
  select screen).

Despite these issues, Drider can actually be used to read things! It
works best on text-heavy, low-formatting books such as novels.

Put your ebooks in a folder called `books` at the root of your sd card.

## Controls

Selecting:

- Up and Down on the d-pad or circle-pad to choose a book to read.
- A button to select the book.
- X button to toggle loading of images.
- Start button to exit.
- Home button to return to the Home menu (cia-only).

Reading:

- Up and Down on the d-pad or circle-pad to scroll. You can also drag
  the touch screen.
- Left and Right on the d-pad to switch pages.
- A button to bookmark a page. Press A again on the same page to
  unbookmark it. If an ebook has a page bookmarked then drider will jump
  to that page when you load the ebook. Only one page can be bookmarked
  at a time per ebook.
- Tap an image on the touchscreen to view it more closely.
- Start button to exit.
- Select button to go back to the book selection.
- Home button to return to the Home menu (cia-only).

Image viewing:

- Circle-pad will pan across the image.
- Up and Down on the d-pad will zoom in and out respectively.
- B button to return to the page you were reading.
- Start button to exit.
- Home button to return to the Home menu (cia-only).

## Installing

You can download a prepackaged version of Drider from the [releases] page.
Homebrew Launcher users should install the `3ds` directory to the root
of their sd card. Cia users can install the cia file.

[releases]: https://github.com/ingolemo/drider/releases

## Building

If you want to build Drider yourself, you will need a unix-like system and
the [3dstool], [bannertool], and [makerom] utilities must be available
on your `$PATH`. Then you can just run `make`. This will create the
`drider.cia` and a `3ds` folder in the `build` directory. It's probably
possible to build Drider on a Windows system, but the makefile doesn't
support it.

[3dstool]: https://github.com/dnasdw/3dstool
[bannertool]: https://github.com/Steveice10/bannertool
[makerom]: https://github.com/profi200/Project_CTR
