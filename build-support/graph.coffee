assert = require 'assert'


class ProductRelations
  constructor: ->
    @in = new Set
    @out = new Set

  addInput: (taskId) ->
    assert (not @in.has taskId), taskId
    @in.add taskId

  addOutput: (taskId) ->
    assert (not @out.has taskId), taskId
    @out.add taskId


class ProductRegistry
  constructor: ->
    @graph = new Map
    @knownTasks = new Map
    @knownContent = new Map

  ensureNewTask: (task) ->
    taskId = task.identifier()
    assert (not @knownTasks.has taskId), taskId
    @knownTasks.set taskId, task
    taskId

  maybeNewContent: (content) ->
    contentId = content.identifier()
    @knownContent.set contentId, content
    contentId

  setupRelations: (contentId) ->
    if @graph.has contentId
      return @graph.get contentId
    relations = new ProductRelations
    @graph.set contentId, relations
    relations

  registerTask: (task) ->
    taskId = @ensureNewTask task

    for {sources} in task.inputSources()
      for i in sources
        contentId = @maybeNewContent i
        relations = @setupRelations contentId
        relations.addInput taskId
    for {sources} in task.outputSources()
      for o in sources
        contentId = @maybeNewContent o
        relations = @setupRelations contentId
        relations.addOutput taskId
