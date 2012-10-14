async = require 'async'
pandoc = require 'pdc'
fs = require 'fs'
path = require 'path'
url = require 'url'

parseMetadata = (metadata, callback) ->
  ### takes *metadata* in the format:
        key: value
        foo: bar
      returns parsed object ###

  rv = {}
  try
    lines = metadata.split '\n'

    for line in lines
      pos = line.indexOf ':'
      key = line.slice(0, pos).toLowerCase()
      value = line.slice(pos + 1).trim()
      rv[key] = value

    callback null, rv

  catch error
    callback error

extractMetadata = (content, callback) ->
  # split metadata and markdown content
  split_idx = content.indexOf '\n\n' # should probably make this a bit more robust

  async.parallel
    metadata: (callback) ->
      parseMetadata content.slice(0, split_idx), callback
    markdown: (callback) ->
      callback null, content.slice(split_idx + 2)
  , callback
  
q = async.queue((page, callback) ->
  pandoc page._content, 'markdown', 'html', ['--smart', '--mathjax'], (err, result) ->
    page._htmlraw = result
    callback null, page
, 2)

pandocRender = (page, callback) ->
  q.push page, (err, page) ->
    if err
      console.log err
    else
      callback null, page

module.exports = (wintersmith, callback) ->

  class PandocPage extends wintersmith.defaultPlugins.MarkdownPage
    
    getHtml: (base) ->
      # TODO: cleaner way to achieve this?
      # http://stackoverflow.com/a/4890350
      name = @getFilename()
      name = name[name.lastIndexOf('/')+1..]
      loc = @getLocation(base)
      fullName = if name is 'index.html' then loc else loc + name
      # handle links to anchors within the page
      @_html = @_htmlraw.replace(/(<(a|img)[^>]+(href|src)=")(#[^"]+)/g, '$1' + fullName + '$4')
      # handle relative links
      @_html = @_html.replace(/(<(a|img)[^>]+(href|src)=")(?!http|\/)([^"]+)/g, '$1' + loc + '$4')
      # handles non-relative links within the site (e.g. /about)
      if base
        @_html = @_html.replace(/(<(a|img)[^>]+(href|src)=")\/([^"]+)/g, '$1' + base + '/$4')
      return @_html
    
    getIntro: (base) ->
      @_html = @getHtml(base)
      idx = ~@_html.indexOf('<span class="more') or ~@_html.indexOf('<h2') or ~@_html.indexOf('<hr')
      # TODO: simplify!
      if idx
        @_intro = @_html.toString().substr 0, ~idx
        hr_index = @_html.indexOf('<hr')
        footnotes_index = @_html.indexOf('<div class="footnotes">')
        # ignore hr if part of Pandoc's footnote section
        if hr_index && ~footnotes_index && !(hr_index < footnotes_index)
          @_intro = @_html
      else
        @_intro = @_html
      return @_intro
      
    @property 'hasMore', ->
      @_html ?= @getHtml()
      @_intro ?= @getIntro()
      @_hasMore ?= (@_html.length > @_intro.length)
      return @_hasMore
  
  PandocPage.fromFile = (filename, base, callback) ->
    async.waterfall [
      (callback) ->
        fs.readFile path.join(base, filename), callback
      (buffer, callback) ->
        extractMetadata buffer.toString(), callback
      (result, callback) =>
        {markdown, metadata} = result
        page = new this filename, markdown, metadata
        callback null, page
      (page, callback) =>
        pandocRender page, callback
      (page, callback) =>
        callback null, page
    ], callback
   
  wintersmith.registerContentPlugin 'pages', '**/*.*(markdown|mkd|md)', PandocPage

  callback()
