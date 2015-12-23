{normalizeRange, rangesAreEqual} = Trix

deepCopy = (object) ->
  result = {}
  for key, value of object
    result[key] = switch
      when Array.isArray(value)
        value.slice(0)
      when typeof value is "object"
        deepCopy(value)
      else
        value
  result

originalConfig = deepCopy(Trix.config)

initialized = false
initializedCallbacks = []

document.addEventListener "trix-initialize", ->
  initialized = true
  callback() while callback = initializedCallbacks.shift()

editorInitialized = (callback) ->
  if initialized
    callback()
  else
    initializedCallbacks.push(callback)

setTemplate = (template) ->
  initialized = false
  setFixtureHTML(JST["test_helpers/fixtures/#{template}"]())

@after = (defer, callback) ->
  setTimeout(callback, defer)

@defer = (callback) -> after 1, callback

@editorModule = (name, {template, setup, teardown} = {}) ->
  module name,
    setup: ->
      if template?
        setTemplate(template)
      setup?()

    teardown: ->
      if template?
        setFixtureHTML("")
      teardown?()

@editorTest = (name, options = {}, callback) ->
  if callback?
    {template, setup, teardown} = options
  else
    callback = options

  done = (expectedDocumentValue) ->
    if expectedDocumentValue
      equal getDocument().toString(), expectedDocumentValue
    teardown?()
    QUnit.start()

  asyncTest name, ->
    setup?()
    setTemplate(template) if template?

    editorInitialized ->
      if getEditorElement().hasAttribute("autofocus")
        getEditorController().setLocationRange(index: 0, offset: 0)

      if callback.length is 0
        callback()
        done()
      else
        callback done

@editorConfigTest = (name, {template, setup, teardown}, callback) ->
  editorTest name,
    template: template ? "editor_empty"
    setup: setup
    teardown: ->
      Trix.config = deepCopy(originalConfig)
      teardown?()
    , callback

@assertLocationRange = (start, end) ->
  expectedLocationRange = normalizeRange([start, end])
  actualLocationRange = getEditorController().getLocationRange()
  ok rangesAreEqual(expectedLocationRange, actualLocationRange), "expected #{JSON.stringify(expectedLocationRange)}, actual #{JSON.stringify(actualLocationRange)}"

@expectAttributes = (range, attributes) ->
  document = getDocument().getDocumentAtRange(range)
  blocks = document.getBlocks()
  throw "range #{JSON.stringify(range)} spans more than one block" unless blocks.length is 1

  locationRange = getDocument().locationRangeFromRange(range)
  textIndex = locationRange[0].index
  textRange = [locationRange[0].offset, locationRange[1].offset]
  text = getDocument().getTextAtIndex(textIndex).getTextAtRange(textRange)
  pieces = text.getPieces()
  throw "range #{JSON.stringify(range)} must only span one piece" unless pieces.length is 1

  piece = pieces[0]
  deepEqual piece.getAttributes(), attributes

@expectBlockAttributes = (range, attributes) ->
  document = getDocument().getDocumentAtRange(range)
  blocks = document.getBlocks()
  throw "range #{JSON.stringify(range)} spans more than one block" unless blocks.length is 1

  block = blocks[0]
  deepEqual block.getAttributes(), attributes

@expectHTML = (trixDocument, html) ->
  equal getHTML(trixDocument), html

@getHTML = (trixDocument) ->
  Trix.DocumentView.render(trixDocument).innerHTML

setFixtureHTML = (html) ->
  element = findOrCreateTrixContainer()
  element.innerHTML = html

findOrCreateTrixContainer = ->
  if container = document.getElementById("trix-container")
    container
  else
    document.body.insertAdjacentHTML("afterbegin", """<form id="trix-container"></form>""")
    document.getElementById("trix-container")
