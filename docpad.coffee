# DocPad Configuration File
# http://docpad.org/docs/config

# Define the DocPad Configuration
docpadConfig = {
    watchOptions:
        preferredMethods: ['watchFile', 'watch']

    templateData:
        getLitcoffeeData: ->
            path = require 'path'
            filename = path.join @document.fullDirPath, @document.litcoffeeFile

            docco       = require 'docco'
            {highlight} = require 'highlight.js'
            marked      = require 'marked'
            fs          = require 'fs'

            content = fs.readFileSync(filename).toString()
            sections = docco.parse filename, content

            for section in sections
              section.codeHtml = highlight('coffeescript', section.codeText).value
              section.docsHtml = marked(section.docsText)

            return sections
}

# Export the DocPad Configuration
module.exports = docpadConfig
