# USAGE:  $> ruby update_nest_test.rb [{true|false}]   (false is default)

require 'rubygems'
require 'bundler'
Bundler.setup

require 'mongoid'
require 'ruby-debug'

puts "Using Mongoid: #{Mongoid::VERSION}"

Mongoid.master = Mongo::Connection.new.db("nest_test")

# If command line arg is true, then create the root, then save, then pull it back from the db, then make changes so that _update gets called
# If false (the default) then one big insert is made (initial large insert has always worked)
#
@create_first = (ARGV.first.blank? ? true : ARGV.first) == "true"

#---------------------------

class Publication
  include Mongoid::Document
  include Mongoid::Timestamps
  
  field :title
  #field :score, :class_name => "Object"
  
  embedded_in :envelope, :inverse_of => :publications
  embedded_in :folder, :inverse_of => :publications
  
end

class Essay < Publication 
  field :journal, :type => String
end
class Photo < Publication 
  field :magazines_published_in, :type => Integer
end
#---------------------------
class Folder
  include Mongoid::Document
  field :name
  
  embeds_many :publications
  embedded_in :envelope, :inverse_of => :folders
  
end

#---------------------------

class Envelope
  include Mongoid::Document
  include Mongoid::Timestamps
  
  field :to
  field :from
  field :summary
  
  embeds_many :folders            #papers go inside folder too, which can also go inside envelopes
  embeds_many :publications       #publications go inside envelopes
  embeds_many :envelopes          #envelopes also go inside larger envelopes

  embeds_many :secret_compartments, :class_name => "FancyEnvelope"
  
end

class Portfolio < Envelope
  field :subject 
end

class PersonalFile < Envelope
end

class FancyEnvelope < Envelope
  attr_accessor :status
  field :why_im_so_fancy
end

class PinkFeatheredEnvelope < FancyEnvelope; 
  before_save :set_why
  def set_why
    self.why_im_so_fancy = "So sparkly and glittery."
  end
end
#---------------------------
def spacer; puts "\n\n"; end

def myrand
  (0...5).map{65.+(rand(25)).chr}.join
end
#---------------------------


Envelope.delete_all

############################

spacer
puts "Creating Publications..."

puts "Generating Essays..."
@essay_poverty = Essay.new :title => "World Poverty", :journal => "National Geographic"
@essay_starcraft = Essay.new :title => "Starcraft as Allegory", :journal => "Nerd Nation"
@essay_protein = Essay.new :title => "Protein Synthesis", :journal => "Nature"
@essay_spca = Essay.new :title => "SPCA Increases Funding", :journal => "Animal World"
@essay_mongoid = Essay.new :title => "How to use Mongoid", :journal => "Slashdot"

puts "Generating Photos..."
@photo_dog = Photo.new :title => "Fluffy Fights Back", :magazines_published_in => 3
@photo_cat = Photo.new :title => "Making Fluffy Cry", :magazines_published_in => 88
@photo_rain = Photo.new :title => "NYC Rain", :magazines_published_in => 2

puts "Generating Folders..."
@folder_animals = Folder.new :name => "Stuff About Animals"

puts "Stuffing Animal-Related Stuff in Animal Folder..."
@folder_animals.publications << @photo_dog
@folder_animals.publications << @photo_cat
@folder_animals.publications << @essay_spca

puts "Generating Envelopes..."
@portfolio = Portfolio.new :to => "The World", :from => "me", :subject => "Things That Have Been Professionally Published"
@personal_file = PersonalFile.new :summary => "My Personal Stuff for Only Me to See"
@pinky = PinkFeatheredEnvelope.new :summary => "To Add Sparkles"


############################

spacer
puts "Creating Root Envelope..."
@ENV = Envelope.new :to => "durran", :from => "ryan", :summary => "Root Envelope (it's really big)"

if @create_first
  puts "Root Envelope Save..." 
  @ENV.save 
end

if @create_first
  puts "Retreiving Root Envelope That We Just Created..." 
  @ENV = Envelope.first 
end

puts "Stuffing @portfolio..."
@portfolio.publications << @essay_poverty
@portfolio.publications << @essay_starcraft
@portfolio.publications << @photo_rain
@ENV.envelopes << @portfolio

@ENV.publications << (Essay.new :title => "Ad Hoc Writing on the Fly", :journal => "Writer's World")

puts "Putting Animal Folder in Pink Fancy Envelope..."
@pinky.folders << @folder_animals
@ENV.envelopes.first.envelopes << @pinky

if @create_first
  puts "Saving Envelope..."
  @ENV.save
  puts "More Edits..."
end

@ENV.envelopes.first.publications << @essay_mongoid

@ENV.save

@ENV.envelopes.first.envelopes.first.secret_compartments << (FancyEnvelope.new :summary => "Top Secret Compartment")
@ENV.save


@ENV = Envelope.first 


__END__

Mongo Output:

> db.envelopes.find()
{ "_id" : ObjectId("4c70fbcaf277f9388d00000d"), "_type" : "Envelope", "created_at" : "Sun Aug 22 2010 03:28:26 GMT-0700 (PDT)", "envelopes" : [
	{
		"_id" : ObjectId("4c70fbcaf277f9388d00000a"),
		"_path" : "envelopes.0",
		"_type" : "Portfolio",
		"envelopes" : [
			{
				"_id" : ObjectId("4c70fbcaf277f9388d00000c"),
				"_path" : "envelopes.0.envelopes.0",
				"_type" : "PinkFeatheredEnvelope",
				"folders" : [
					{
						"_id" : ObjectId("4c70fbcaf277f9388d000009"),
						"_path" : "envelopes.0.envelopes.0.folders.0",
						"name" : "Stuff About Animals",
						"publications" : [
							{
								"title" : "Fluffy Fights Back",
								"magazines_published_in" : 3,
								"_path" : "envelopes.0.envelopes.0.folders.0.publications.0",
								"_id" : ObjectId("4c70fbcaf277f9388d000006"),
								"_type" : "Photo"
							},
							{
								"title" : "Making Fluffy Cry",
								"magazines_published_in" : 88,
								"_path" : "envelopes.0.envelopes.0.folders.0.publications.1",
								"_id" : ObjectId("4c70fbcaf277f9388d000007"),
								"_type" : "Photo"
							},
							{
								"title" : "SPCA Increases Funding",
								"journal" : "Animal World",
								"_path" : "envelopes.0.envelopes.0.folders.0.publications.2",
								"_id" : ObjectId("4c70fbcaf277f9388d000004"),
								"_type" : "Essay"
							}
						]
					}
				],
				"secret_compartments" : [
					{
						"_path" : "envelopes.0.envelopes.0.secret_compartments.0",
						"_id" : ObjectId("4c70fbcaf277f9388d00000f"),
						"_type" : "FancyEnvelope",
						"summary" : "Top Secret Compartment"
					}
				],
				"summary" : "To Add Sparkles"
			}
		],
		"from" : "me",
		"publications" : [
			{
				"title" : "World Poverty",
				"journal" : "National Geographic",
				"_path" : "envelopes.0.publications.0",
				"_id" : ObjectId("4c70fbcaf277f9388d000001"),
				"_type" : "Essay"
			},
			{
				"title" : "Starcraft as Allegory",
				"journal" : "Nerd Nation",
				"_path" : "envelopes.0.publications.1",
				"_id" : ObjectId("4c70fbcaf277f9388d000002"),
				"_type" : "Essay"
			},
			{
				"title" : "NYC Rain",
				"magazines_published_in" : 2,
				"_path" : "envelopes.0.publications.2",
				"_id" : ObjectId("4c70fbcaf277f9388d000008"),
				"_type" : "Photo"
			},
			{
				"title" : "How to use Mongoid",
				"journal" : "Slashdot",
				"_path" : "envelopes.0.publications.3",
				"_id" : ObjectId("4c70fbcaf277f9388d000005"),
				"_type" : "Essay"
			}
		],
		"subject" : "Things That Have Been Professionally Published",
		"to" : "The World"
	}
], "from" : "ryan", "publications" : [
	{
		"title" : "Ad Hoc Writing on the Fly",
		"journal" : "Writer's World",
		"_path" : "publications.0",
		"_id" : ObjectId("4c70fbcaf277f9388d00000e"),
		"_type" : "Essay"
	}
], "summary" : "Root Envelope (it's really big)", "to" : "durran", "updated_at" : "Sun Aug 22 2010 03:28:26 GMT-0700 (PDT)" }
