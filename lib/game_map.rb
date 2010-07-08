class GameMap < ActiveRecord::Base
  AJAX_CONTENT_TYPE = 'application/x-www-form-urlencoded; charset=UTF-8'

  def self.generate_maps(agent)
    get_maps(agent,CATSLE_X,CATSLE_Y).each do |k,v|
      GameMap.create({:x => v['x'], :y => v['y'], :mapid => k, :akuma => v['type'] == 17, :map_type => v['type']})
    end
  end

  def self.get_maps(agent,center_x,center_y)
    ids = generate_map_ids(center_x,center_y)
    json = "json={'mapIds':'#{ids.join(',')}'}"
    map = agent.post("#{DOMAIN}ajaxmap.ql",json,'Content-Type' => AJAX_CONTENT_TYPE)
    JSON.parse(map.body)
  end


  private

  def self.generate_map_ids(center_x,center_y)
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
