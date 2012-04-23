traverse = require 'traverse'
isArray = Array.isArray

module.exports = (namesParam="inline", recursiveParam="inlineRecursive", opts={}) ->

  nameRegex = RegExp "#{namesParam}=([^&]*)&?"
  recurseRegex = recursiveParam and RegExp "#{recursiveParam}(=[^&]*&?)?"

  include: ->

    storeInlineParam = (req, res, next) ->
      ### Strip out and store inlining query parameters ###
      names = nameRegex.exec req.url
      if names
        req.url = req.url.replace names[0], ''
        req.inlineContext ?= {}
        req.inlineContext.keys = names[1].split ','
        if recurseRegex
          recurse = recurseRegex.exec req.url
          if recurse
            req.url = req.url.replace recurse[0], ''
            req.inlineContext.recursive = true
      next()


    makeNestedRequests = (req, res, next) ->
      ### Find and replace inline-able keys ###

      inline = req.inlineContext
      return next() unless inline?.keys
      return next() if not inline.recursive and inline.retrieved?

      inline.pending ?= {}
      inline.retrieved ?= {}
      inline.errors ?= {}

      # Counter of pending requests local to this parent request
      counter = 1
      traverse(res.data).forEach (maybeURL) ->
        return if typeof maybeURL isnt 'string'
        return if maybeURL.substring(0,1) isnt '/'
        parentKey = @path[@path.length - if isArray @parent.node then 2 else 1]
        return if parentKey not in inline.keys

        url = maybeURL
        if inline.errors[url]
          return
        if data = inline.retrieved[url]
          @update data
        if inline.pending[url]
          inline.pending[url].push [res.data, @path]
        else
          inline.pending[url] = [ [res.data, @path] ]

          counter++
          nestedGet url, inline, (err, data) ->
            pending = inline.pending[url]
            delete inline.pending[url]
            if err
              inline.errors[url] = err
            else
              inline.retrieved[url] = data
              for [baseObject, path] in pending
                updatePath baseObject, path, data

            next() unless --counter

      next() unless --counter
    
    updatePath = (baseObject, path, newData) ->
      ### does what you think it would ###
      len = path.length
      pathToObject = path.slice(0, len - 1)
      finalKey = path[len - 1]
      object = baseObject
      for key in pathToObject
        object = object[key]
      object[finalKey] = newData


    nestedGet = (url, inlineContext, done) =>
      ###
      fake a GET request against the slice of stack following the
      ``storeInlineParam`` middleware up to and including the
      ``makeNestedRequests`` middleware. 
      ###
      startIndex = (@_stack.indexOf storeInlineParam) + 1
      endIndex = (@_stack.indexOf makeNestedRequests) + 1
      stack = @_stack.slice(startIndex, endIndex)

      if opts.skipMiddleware
        stack = stack.filter (mw) -> mw not in opts.skipMiddleware


      req = {url, method: 'GET'}
      req.inlineContext = inlineContext if inlineContext.recursive
      partialRequest stack, req, done

    partialRequest = (stack, req, done) ->
      res =
        end: (data='') ->
          # XXX - depends on end being called with JSON, probably bad
          res.data = JSON.parse data
          done()
        setHeader: (name, header) ->

      i = 0
      next = (err) ->
        return done err if err
        mw = stack.shift()
        return done null, res.data unless mw
        mw(req, res, next)
      next()

    @before opts.startBefore or @findResource, storeInlineParam
    @before opts.endBefore or @renderResponse, makeNestedRequests
    @helper
      getResource: (shortName, vars, cb) ->
        startIndex = (@app._stack.indexOf @app.dispatchHandler)
        endIndex = (@app._stack.indexOf makeNestedRequests)
        stack = @_stack.slice(startIndex, endIndex)
        req = {vars, method: 'GET'}
        partialRequest stack, req, cb
      postResource: (shortName, vars, body, cb) ->
        startIndex = (@app._stack.indexOf @app.dispatchHandler)
        endIndex = (@app._stack.indexOf makeNestedRequests)
        stack = @_stack.slice(startIndex, endIndex)
        req = {vars, body, method: 'POST'}
        partialRequest stack, req, cb
      
