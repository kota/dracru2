require 'dracru2'

if File.exists?(File.join(TMP_PATH, 'stop.txt'))
  $logger.info("Raid was stopped. Remove tmp/stop.txt if you want to raid again.")
  exit
end
dracru2 = Dracru2.new
dracru2.raid_if_possible
