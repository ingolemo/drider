![Drider 3ds epub reader](banner.png)


# Drider

Drider is a epub reader for the Nintendo 3ds. In order to run it you
will need a way to run homebrew applications on your 3ds. It is written
in Lua using Rinnegatamante's [Lua Player Plus 3ds].

Drider has a few limitations:

* It does not support images. They will be rendered as grey boxes so at
  least you know there was supposed to be an image there.
* It does not support css or any kind of inline styling, such as &lt;b&gt;
  or &lt;i&gt; tags.
* It doesn't handle non-ascii text well. If you're reading a utf-8
  encoded book then it tries to translate some of the most common
  symbols to ascii equivalents, but the conversion is incomplete so
  mojibake is common.
* Text rendering on the 3ds is not very good so you will see plenty of
  bad kerning.

Despite these issues, Drider can actually be used to read things! It
works best on text-heavy, low-formatting books such as novels.

Put your ebooks in a folder called `books` at the root of your sd card.

## Controls

Selecting:

* Up and Down on the d-dpad to choose a book to read
* A button to select the book.
* Start button to exit.
* Home button to return to the Home menu (cia-only).

Reading:

* Up and Down on the d-pad or circle-pad to scroll. You can also drag
  the touch screen.
* Left and Right on the d-pad to switch pages.
* A button to bookmark a page. Press A again on the same page to
  unbookmark it. If an ebook has a page bookmarked then drider will jump
  to that page when you load the ebook.
* Start button to exit.
* Select button to go back to the book selection.
* Home button to return to the Home menu (cia-only).


## Building and Installing

The `Makefile` provided is for a unix-like system. You will need to have
the [3dstool], [bannertool], and [makerom] utilities available on your
`$PATH` and then you can just type `make`. This will produce a
`drider.cia` and a `3ds` folder in the `build` directory.

Homebrew Launcher users should install the `3ds` directory to the root
of their sd card. Cia users can install the cia file.

[Lua Player Plus 3ds]: https://github.com/Rinnegatamante/lpp-3ds "lpp-3ds"
[3dstool]: https://github.com/dnasdw/3dstool
[bannertool]: https://github.com/Steveice10/bannertool
[makerom]: https://github.com/profi200/Project_CTR
