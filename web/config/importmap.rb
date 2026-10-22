# frozen_string_literal: true

# Pin npm packages by running ./bin/importmap

pin 'application'
pin '@hotwired/turbo-rails', to: 'turbo.min.js'
pin '@hotwired/stimulus', to: 'stimulus.min.js'
pin '@hotwired/stimulus-loading', to: 'stimulus-loading.js'
pin_all_from 'app/javascript/controllers', under: 'controllers', preload: false
pin_all_from 'app/javascript/helpers', under: 'helpers', preload: false
pin 'lexxy', to: 'lexxy.js'
pin '@rails/activestorage', to: 'activestorage.esm.js'
pin "@rails/request.js", to: "@rails--request.js.js" # @0.0.13
