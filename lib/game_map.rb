class GameMap < ActiveRecord::Base
  AJAX_CONTENT_TYPE = 'application/x-www-form-urlencoded; charset=UTF-8'

  def self.generate_maps(agent)
    get_centers_of_neighbour(CATSLE_X,CATSLE_Y,RAID_DISTANCE).each do |coord|
      get_maps(agent,coord[:x],coord[:y]).each do |k,v|
        if ['丘陵','森林','湿地','山地'].include?(v['name'])
          GameMap.create({:x => v['x'], :y => v['y'], :mapid => k, :akuma => v['type'] == 17, :map_type => v['name']})
        end
      end
    end
  end

  def self.get_maps(agent,center_x,center_y)
    ids = get_map_ids(center_x,center_y)
    json = "json={'mapIds':'#{ids.join(',')}'}"
    map = agent.post("#{DOMAIN}ajaxmap.ql",json,'Content-Type' => AJAX_CONTENT_TYPE)
    JSON.parse(map.body)
  end

  private

  #distance = 画面単位ではかった距離
  # ex. distance = 1
  # * * *
  # * c *
  # * * *
  #
  # ex. ditance = 2
  # * * * * *
  # *       *
  # *   c   *
  # *       *
  # * * * * *
  #
  # return 上図*の画面の中心座標の配列
  #
  def self.get_centers_of_neighbour(center_x,center_y,distance)
    centers = []
    dist_in_grids = distance * 9
    (distance*2+1).times do |i| 
      diff = i*9
      centers.push({:x => center_x-dist_in_grids+diff, :y => center_y-dist_in_grids})
      centers.push({:x => center_x-dist_in_grids, :y => center_y-dist_in_grids+diff})
      centers.push({:x => center_x+dist_in_grids-diff, :y => center_y+dist_in_grids})
      centers.push({:x => center_x+dist_in_grids, :y => center_y+dist_in_grids-diff})
    end
    centers.uniq
  end

  def self.get_map_ids(center_x,center_y)
    ids = []
    (-4..4).each do |x|
      (-4..4).each do |y|
        ids.push(get_map_id(center_x+x,center_y+y))
      end
    end
    ids
  end

  def self.get_map_id(x,y)
    ((x+5000)*10000)+y+5000
  end

end
