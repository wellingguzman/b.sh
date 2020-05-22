# b.sh simple site generator

This is the result of trying to learn how to make a basic site generator with bash. Not meant to be used, but if so, **use it  at your own risk**.

## Usage

```bash
# create/edit document
b.sh c hello.html

# build document
b.sh b hello.html

# build all documents
b.sh ba
```

All commands above will regenerate the index page.

### Directory structure

By default the source documents are going to be save in `./posts/` and the generated files inside `./public/`.

To use markdown you must set markdown path in `g_markdown` variable.
