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
require 'faker'

require_relative '../../lib/documents'

describe Documents do
  include Radish::Randomness
  
  it 'should store a document in the rules collection with a generated id' do
    types = ['rule', 'table']

    rand_array do
      {
        doc: {
          'meta' => { 'version' => Faker::App.semantic_version },
        },
        src: rand_document.merge({
                                   'ns' => Faker::Lorem.word,
                                   'name' => Faker::Lorem.word,
                                 }),
        id: Faker::Number.hexadecimal(40),
      }
    end.each do |o|
      th = types.sample
      ex_inserted_doc = o[:src].merge(content: o[:doc], public_id: o[:id], thing: th)
      
      conn = double('Fake: mongo connection')
      coll = double('Fake: mongo rules collection')
      expect(conn).to receive('[]').with('rules').and_return(coll)
      expect(coll).to receive(:insert_one).with(ex_inserted_doc)

      docs = Documents.new
      expect(docs).to receive(:connection).and_return(conn)
      docs.store_rule(th, o[:id], o[:src], o[:doc])
    end
  end

  it 'should store table data' do
    rand_array do
      rand_array do
        rand_document
      end
    end.each do |table_data|
      conn = double('Fake: mongo connection')
      coll = double('Fake: mongo rules collection')
      
      expect(conn).to receive('[]').with('table_data').and_return(coll)
      expect(coll).to receive(:insert_one).with(table_data)

      docs = Documents.new
      expect(docs).to receive(:connection).and_return(conn)
      docs.store_table_data(table_data)
    end
  end

  it 'should remove rules by origin, branch' do
    rand_times do
      origin = Faker::Internet.url
      branch = Faker::Lorem.word

      conn = double('Fake: mongo connection')
      coll = double('Fake: mongo rules collection')

      expect(conn).to receive('[]').with('rules').and_return(coll)
      expect(coll).to receive(:delete_many).with(origin: origin, branch: branch)

      docs = Documents.new
      expect(docs).to receive(:connection).and_return(conn)
      docs.remove_rules_by_origin_branch(origin, branch)
    end
  end

  it 'should remove table data by origin, branch' do
    rand_times do
      origin = Faker::Internet.url
      branch = Faker::Lorem.word

      conn = double('Fake: mongo connection')
      coll = double('Fake: mongo rules collection')

      expect(conn).to receive('[]').with('table_data').and_return(coll)
      expect(coll).to receive(:delete_many).with(origin: origin, branch: branch)

      docs = Documents.new
      expect(docs).to receive(:connection).and_return(conn)
      docs.remove_table_data_by_origin_branch(origin, branch)
    end
  end

  it 'should remove a rule by rule_id' do
    rand_times do
      rule_id = Faker::Number.hexadecimal(40)

      conn = double('Fake: mongo connection')
      coll = double('Fake: mongo rules collection')

      expect(conn).to receive('[]').with('rules').and_return(coll)
      expect(coll).to receive(:delete_many).with(public_id: rule_id)

      docs = Documents.new
      expect(docs).to receive(:connection).and_return(conn)
      docs.remove_rule_by_id(rule_id)      
    end
  end

  it 'should list all instances of a rule across branches' do
    rand_times do
      rule_id = Faker::Number.hexadecimal(40)
      exes = rand_array do
        {
          id: rule_id,
          origin: Faker::Internet.url,
          branch: Faker::Lorem.word,
        }
      end

      results = exes.map do |ex|
        rand_document.merge({
          'public_id' => ex[:id],
          'origin' => ex[:origin],
          'branch' => ex[:branch],
        })
      end

      conn = double('Fake: mongo connection')
      coll = double('Fake: mongo rules collection')

      expect(conn).to receive('[]').with('rules').and_return(coll)
      expect(coll).to receive(:find).with(public_id: rule_id).and_return(results)

      docs = Documents.new
      expect(docs).to receive(:connection).and_return(conn)

      expect(docs.lookup_rule_branches(rule_id)).to eql(exes)
    end
  end

  it 'should remove table data based on origin, branch, ns, name' do
    rand_times do
      origin = Faker::Internet.url
      branch = Faker::Lorem.word
      ns = Faker::Lorem.word
      name = Faker::Lorem.word

      conn = double('Fake: mongo connection')
      coll = double('Fake: mongo rules collection')

      expect(conn).to receive('[]').with('table_data').and_return(coll)
      expect(coll).to receive(:delete_many).with(origin: origin, branch: branch, ns: ns, name: name)

      docs = Documents.new
      expect(docs).to receive(:connection).and_return(conn)
      docs.remove_specific_table_data(origin, branch, ns, name)
    end
  end
end