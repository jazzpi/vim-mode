fs = require 'fs-plus'
{saveAs, getFullPath} = require './utils'
CommandError = require './command-error'

trySave = (func) ->
  deferred = Promise.defer()

  try
    func()
    deferred.resolve()
  catch error
    if error.message.endsWith('is a directory')
      atom.notifications.addWarning("Unable to save file: #{error.message}")
    else if error.path?
      if error.code is 'EACCES'
        atom.notifications
          .addWarning("Unable to save file: Permission denied '#{error.path}'")
      else if error.code in ['EPERM', 'EBUSY', 'UNKNOWN', 'EEXIST']
        atom.notifications.addWarning("Unable to save file '#{error.path}'",
          detail: error.message)
      else if error.code is 'EROFS'
        atom.notifications.addWarning(
          "Unable to save file: Read-only file system '#{error.path}'")
    else if (errorMatch =
        /ENOTDIR, not a directory '([^']+)'/.exec(error.message))
      fileName = errorMatch[1]
      atom.notifications.addWarning("Unable to save file: A directory in the "+
        "path '#{fileName}' could not be written to")
    else
      throw error

  deferred.promise

module.exports =
  class ExCommands
    @commands =
      'quit':
        priority: 1000
        callback: ->
          atom.workspace.getActivePane().destroyActiveItem()
      'qall':
        priority: 1000
        callback: ->
          atom.close()
      'tabnext':
        priority: 1000
        callback: ({editor}) ->
          atom.workspace.getActivePane().activateNextItem()
      'tabprevious':
        priority: 1000
        callback: ({editor}) ->
          atom.workspace.getActivePane().activatePreviousItem()
      'write':
        priority: 1001
        callback: ({editor, args}) ->
          if args[0] is '!'
            force = true
            args = args[1..]

          filePath = args.trimLeft()
          if /[^\\] /.test(filePath)
            throw new CommandError('Only one file name allowed')
          filePath = filePath.replace('\\ ', ' ')

          deferred = Promise.defer()

          if filePath.length isnt 0
            fullPath = getFullPath(filePath)
          else if editor.getPath()?
            trySave(-> editor.save())
              .then(deferred.resolve)
          else
            fullPath = atom.showSaveDialogSync()

          if fullPath?
            if not force and fs.existsSync(fullPath)
              throw new CommandError("File exists (add ! to override)")
            trySave(-> saveAs(fullPath, editor))
              .then(deferred.resolve)

          deferred.promise
      'update':
        priority: 1000
        callback: (ev) =>
          @callCommand('write', ev)
      'wall':
        priority: 1000
        callback: ->
          # FIXME: This is undocumented for quite a while now - not even
          #        deprecated. Should probably use PaneContainer::saveAll
          atom.workspace.saveAll()
      'wq':
        priority: 1000
        callback: (ev) =>
          @callCommand('write', ev).then => @callCommand('quit')
      'xit':
        priority: 1000
        callback: (ev) =>
          @callCommand('wq', ev)
      'exit':
        priority: 1000
        callback: (ev) => @callCommand('xit', ev)
      'xall':
        priority: 1000
        callback: (ev) =>
          atom.workspace.saveAll()
          @callCommand('qall')

    @registerCommand: ({name, priority, callback}) =>
      @commands[name] = {priority, callback}

    @callCommand: (name, ev) =>
      @commands[name].callback(ev)
