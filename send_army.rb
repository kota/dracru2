$: << File.dirname(__FILE__)
require 'dracru2'

if File.exists?(File.join(TMP_PATH, 'stop.txt'))
  $logger.info("Raid was stopped. Remove tmp/stop.txt if you want to raid again.")
  exit
end
if File.exists?(File.join(TMP_PATH, 'skip.txt'))
  File.delete(File.join(TMP_PATH, 'skip.txt'))
  $logger.info("This raid was skipped.")
  exit
end
dracru2 = Dracru2.new
dracru2.send_army_if_possible
