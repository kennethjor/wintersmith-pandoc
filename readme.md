# wintersmith-pandoc

[Pandoc](http://johnmacfarlane.net/pandoc/) plugin for [wintersmith](https://github.com/jnordberg/wintersmith). Renders Markdown content using Pandoc instead of the default, [marked](https://github.com/chjj/marked). While slower to render, this enables lots of Markdown extras such as footnotes, tables, strikethrough, LaTeX math (via [MathML](http://www.mathjax.com)), and smart punctuation.

### install:

    npm install wintersmith-pandoc
  
then add `./node_modules/wintersmith-pandoc/` to `config.json` like:

    {
      "locals": {
        "url": "http://localhost:8080",
        "name": "The Wintersmith's blog",
        "owner": "The Wintersmith",
        "description": "-32°C ain't no problems!",
        "index_articles": 3
      },
      "plugins": [
        "./node_modules/wintersmith-pandoc/"
      ]
    }
