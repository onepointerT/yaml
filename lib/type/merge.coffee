resolveYamlMerge = (data) ->
    data == '<<' or data == null

'use strict'
Type = require('../type')
module.exports = new Type('tag:yaml.org,2002:merge',
    kind: 'scalar'
    resolve: resolveYamlMerge)
