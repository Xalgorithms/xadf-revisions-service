# Copyright (C) 2018 Don Kelly <karfai@gmail.com>
# Copyright (C) 2018 Hayk Pilosyan <hayk.pilos@gmail.com>

# This file is part of Interlibr, a functional component of an
# Internet of Rules (IoR).

# ACKNOWLEDGEMENTS
# Funds: Xalgorithms Foundation
# Collaborators: Don Kelly, Joseph Potvin and Bill Olders.

# This program is free software: you can redistribute it and/or
# modify it under the terms of the GNU Affero General Public License
# as published by the Free Software Foundation, either version 3 of
# the License, or (at your option) any later version.

# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# Affero General Public License for more details.

# You should have received a copy of the GNU Affero General Public
# License along with this program. If not, see
# <http://www.gnu.org/licenses/>.
require 'active_support/core_ext/string'
require 'mongo'

require_relative './ids'
require_relative './local_env'

class Documents
  include Ids
  
  def initialize
    @env = LocalEnv.new(
      'MONGO', {
        url: { type: :string, default: 'mongodb://127.0.0.1:27017/interlibr' },
      })
  end

  def store_rule(t, src, doc)
    public_id = make_id(t, src.merge('version' => doc.fetch('meta', {}).fetch('version', nil)))
    connection['rules'].insert_one(src.merge(content: doc, public_id: public_id, thing: t))
    puts "# stored (thing=#{t}; public_id=#{public_id})"

    public_id
  end

  def store_table_data(data)
    connection['table_data'].insert_one(data)
  end
  
  private

  def connection
    @cl ||= connect
  end

  def connect
    url = @env.get(:url)
    
    puts "> connecting to Mongo (url=#{url})"
    cl = Mongo::Client.new(url)
    puts "< connected"

    cl
  end

  def store_thing(t, src, doc)
  end
end
