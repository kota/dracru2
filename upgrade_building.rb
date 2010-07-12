$: << File.dirname(__FILE__)
require 'dracru2'

dracru2 = Dracru2.new
dracru2.build_or_upgrade_if_queued
