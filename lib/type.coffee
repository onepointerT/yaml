compileStyleAliases = (map) ->
    result = {}
    if map != null
        Object.keys(map).forEach (style) ->
            map[style].forEach (alias) ->
                result[String(alias)] = style
                return
            return
    result

Type = (tag, options) ->
    options = options or {}
    Object.keys(options).forEach (name) ->
        if TYPE_CONSTRUCTOR_OPTIONS.indexOf(name) == -1
            throw new YAMLException('Unknown option "' + name + '" is met in definition of "' + tag + '" YAML type.')
        return
    # TODO: Add tag format check.
    @options = options
    # keep original options in case user wants to extend this type later
    @tag = tag
    @kind = options['kind'] or null
    @resolve = options['resolve'] or ->
        true
    @construct = options['construct'] or (data) ->
        data
    @instanceOf = options['instanceOf'] or null
    @predicate = options['predicate'] or null
    @represent = options['represent'] or null
    @representName = options['representName'] or null
    @defaultStyle = options['defaultStyle'] or null
    @multi = options['multi'] or false
    @styleAliases = compileStyleAliases(options['styleAliases'] or null)
    if YAML_NODE_KINDS.indexOf(@kind) == -1
        throw new YAMLException('Unknown kind "' + @kind + '" is specified for "' + tag + '" YAML type.')
    return

'use strict'
YAMLException = require('./exception')
TYPE_CONSTRUCTOR_OPTIONS = [
    'kind'
    'multi'
    'resolve'
    'construct'
    'instanceOf'
    'predicate'
    'represent'
    'representName'
    'defaultStyle'
    'styleAliases'
]
YAML_NODE_KINDS = [
    'scalar'
    'sequence'
    'mapping'
]
module.exports = Type
