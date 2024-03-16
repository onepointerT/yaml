# YAML error class. http://stackoverflow.com/questions/8458984
#

formatError = (exception, compact) ->
    where = ''
    message = exception.reason or '(unknown reason)'
    if !exception.mark
        return message
    if exception.mark.name
        where += 'in "' + exception.mark.name + '" '
    where += '(' + exception.mark.line + 1 + ':' + exception.mark.column + 1 + ')'
    if !compact and exception.mark.snippet
        where += '\n\n' + exception.mark.snippet
    message + ' ' + where

YAMLException = (reason, mark) ->
    # Super constructor
    Error.call this
    @name = 'YAMLException'
    @reason = reason
    @mark = mark
    @message = formatError(this, false)
    # Include stack trace in error object
    if Error.captureStackTrace
        # Chrome and NodeJS
        Error.captureStackTrace this, @constructor
    else
        # FF, IE 10+ and Safari 6+. Fallback for others
        @stack = (new Error).stack or ''
    return

'use strict'
# Inherit from Error
YAMLException.prototype = Object.create(Error.prototype)
YAMLException::constructor = YAMLException

YAMLException::toString = (compact) ->
    @name + ': ' + formatError(this, compact)

module.exports = YAMLException
