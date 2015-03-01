async = require 'async'
pandoc = require 'pdc'
fs = require 'fs'
path = require 'path'
url = require 'url'

q = async.queue((page, callback) ->
	pandoc page.markdown, 'markdown', 'html', ['--smart', '--mathjax'], (err, result) ->
		page._htmlraw = result
		callback err, page
, 2)

pandocRender = (page, callback) ->
	q.push page, (err, page) ->
		callback err, page

module.exports = (env, callback) ->
	class PandocPage extends env.plugins.MarkdownPage

		getHtml: (base = env.config.baseUrl) ->
			# TODO: cleaner way to achieve this?
			# http://stackoverflow.com/a/4890350
			name = @getFilename()
			name = name[name.lastIndexOf('/') + 1..]
			loc = @getLocation(base)
			fullName = if name is 'index.html' then loc else loc + name
			# handle links to anchors within the page
			@_html = @_htmlraw.replace(/(<(a|img)[^>]+(href|src)=")(#[^"]+)/g, '$1' + fullName + '$4')
			# handle relative links
			@_html = @_html.replace(/(<(a|img)[^>]+(href|src)=")(?!http|\/)([^"]+)/g, '$1' + loc + '$4')
			# handles non-relative links within the site (e.g. /about)
			if base
				# avoid double '//' entries: remove all tailing '/'-es
				base_adj = base.replace(/[\/]+$/, '')
				# adjust non-relative links so they use this site's base
				@_html = @_html.replace(/(<(a|img)[^>]+(href|src)=")\/([^"]+)/g, '$1' + base_adj + '/$4')
			return @_html

		getIntro: (base = env.config.baseUrl) ->
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

	PandocPage.fromFile = (filepath, callback) ->
		async.waterfall [
			(callback) ->
				fs.readFile filepath.full, callback
			(buffer, callback) ->
				env.plugins.MarkdownPage.extractMetadata buffer.toString(), callback
			(result, callback) =>
				{markdown, metadata} = result
				page = new this filepath, metadata, markdown
				callback null, page
			(page, callback) =>
				pandocRender page, callback
			(page, callback) =>
				callback null, page
		], callback

	env.registerContentPlugin 'pages', '**/*.*(markdown|mkd|md)', PandocPage

	callback()
