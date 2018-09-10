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

require_relative '../../lib/tables'

describe Tables do
  include Radish::Randomness

  def rand_document_collection(ks)
    rand_array do
      ks.inject({}) do |o, k|
        o.merge(k => Faker::Lorem.word)
      end
    end
  end

  class InsertValidation
    attr_reader :queries
    
    def initialize
      @queries = []
    end
    
    def capture(q)
      q.split(';').each do |sub_q|
        m = /INSERT INTO interlibr\.(.+) \((.+)\) VALUES \((.+)\)/.match(sub_q)
        if m
          @queries << {
            tbl: m[1],
            keys: m[2].split(',').sort,
            vals: m[3].split(',').map { |s| s[1..-2] }.sort
          }
        end
      end
    end
  end


  class QueryValidation
    attr_reader :queries
    
    def initialize
      @queries = []
    end
    
    def capture(q)
      m = /SELECT (.+) FROM interlibr\.([a-z]+)(?: WHERE ([^\;]+))?/.match(q)
      if m
        @queries << {
          tbl: m[2],
          keys: m[1].split(',').sort,
          conds: m[3].split(' AND ').map do |c|
            (k, v) = c.split('=')
            { key: k, value: v }
          end
        }
      end
    end
  end
  
  def build_insert_validation(tables)
    validate = InsertValidation.new
    session = double('Fake: Cassandra session')
    stm = double('Fake: Cassandra statement')
    
    expect(tables).to receive(:session).at_least(:once).and_return(session)
    expect(session).to receive(:prepare) do |q|
      validate.capture(q)
      stm
    end
    expect(session).to receive(:execute).with(stm)

    validate
  end

  def build_query_validation(tables, results)
    validate = QueryValidation.new
    session = double('Fake: Cassandra session')
    fut = double('Fake: future')
    
    expect(tables).to receive(:session).at_least(:once).and_return(session)
    expect(session).to receive(:execute_async) do |q|
      validate.capture(q)
      fut
    end
    expect(fut).to receive(:on_success).and_yield(results)
    expect(fut).to receive(:join)

    validate
  end

  def check_one_insert(ac, ex)
    expect(ac[:tbl]).to eql(ex[:tbl])
    expect(ac[:keys]).to eql(ex[:keys])
    expect(ac[:vals]).to eql(ex[:vals])
  end
  
  def check_first_insert(validate, ex)
    check_one_insert(validate.queries.first, ex)
  end

  def check_many_inserts(validate, exes)
    expect(validate.queries.size).to eql(exes.size)
    exes.each_with_index do |ex, i|
      check_one_insert(validate.queries[i], ex)
    end
  end

  def check_one_query(ac, ex)
    expect(ac[:tbl]).to eql(ex[:tbl])
    expect(ac[:keys]).to eql(ex[:keys])
    expect(ac[:conds]).to eql(ex[:conds])
  end
  
  def check_first_query(validate, ex)
    check_one_query(validate.queries.first, ex)
  end

  def build_expectation_from_doc(tbl, doc)
    { tbl: tbl, keys: doc.keys.map(&:to_s).sort, vals: doc.values.sort }
  end

  it 'should store repositories' do
    keys = [:clone_url]

    rand_document_collection(keys).each do |o|
      tables = Tables.new
      validate = build_insert_validation(tables)
      tables.store_repository(o)
      check_first_insert(validate, build_expectation_from_doc('repositories', o))
    end
  end
  
  it 'should store meta data' do
    keys = [:ns, :name, :origin, :branch, :rule_id, :version, :runtime, :criticality]

    rand_document_collection(keys).each do |meta|
      tables = Tables.new
      validate = build_insert_validation(tables)
      tables.store_meta(meta)
      check_first_insert(validate, build_expectation_from_doc('rules', meta))
    end
  end

  it 'should store applicables' do
    when_keys = [:section, :key]
    all_keys = when_keys + [:op, :val, :rule_id]

    rand_array do
      rand_document_collection(all_keys)
    end.each do |apps|
      tables = Tables.new
      validate = build_insert_validation(tables)
      tables.store_applicables(apps)
      
      exes = apps.map do |app|
        build_expectation_from_doc('when_keys', app.slice(*when_keys))
      end + apps.map do |app|
        build_expectation_from_doc('whens', app)
      end
      check_many_inserts(validate, exes)
    end
  end

  it 'should store effectives' do
    keys = [:country, :region, :timezone, :starts, :ends, :key, :rule_id]
    rand_array do
      rand_document_collection(keys)
    end.each do |effs|
      tables = Tables.new
      validate = build_insert_validation(tables)
      tables.store_effectives(effs)
      
      exes = effs.map do |eff|
        build_expectation_from_doc('effective', eff)
      end
      check_many_inserts(validate, exes)
    end
  end

  it 'should call back if a repository exists' do
      tables = Tables.new
      validate = build_query_validation(tables, [rand_document])
      url = Faker::Internet.url

      found = false
      tables.if_has_repository(url) do
        found = true
      end

      expect(found).to eql(true)
      ex = {
        tbl: 'repositories',
        keys: ['*'],
        conds: [
          { key: 'clone_url', value: "'#{url}'" },
        ],
      }
      check_first_query(validate, ex)
  end

  it 'should not call back if a repository does not exist' do
      tables = Tables.new
      validate = build_query_validation(tables, [])
      url = Faker::Internet.url

      found = false
      tables.unless_has_repository(url) do
        found = true
      end

      expect(found).to eql(true)
      ex = {
        tbl: 'repositories',
        keys: ['*'],
        conds: [
          { key: 'clone_url', value: "'#{url}'" },
        ],
      }
      check_first_query(validate, ex)
  end
end
