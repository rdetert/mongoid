require "spec_helper"

describe Mongoid::SoftDeletion do

  let(:collection) do
    stub.quacks_like(Mongoid::Collection.allocate)
  end

  let(:command) do
    stub.quacks_like(Mongoid::Persistence::Remove.allocate)
  end

  describe "#delete!" do

    before do
      @post = ParanoidPost.new
    end

    it "removes the document from the database" do
      Mongoid::Persistence::Remove.expects(:new).with(@post).returns(command)
      command.expects(:persist).returns(true)
      @post.delete!
    end

    it "sets destroyed to true" do
      Mongoid::Persistence::Remove.expects(:new).with(@post).returns(command)
      command.expects(:persist).returns(true)
      @post.delete!
      @post.destroyed?.should == true
    end
  end

  describe "#destroyed?" do

    context "when the document was marked as deleted" do

      before do
        @post = ParanoidPost.new
        @post.deleted_at = Time.now
      end

      it "returns true" do
        @post.destroyed?.should == true
      end
    end

    context "when the document was not marked as deleted" do

      before do
        @post = ParanoidPost.new
      end

      it "returns true" do
        @post.destroyed?.should == false
      end
    end
  end

  describe "#_remove" do

    before do
      @post = ParanoidPost.new
      @post.expects(:collection).returns(collection)
      @time = Time.now
      Time.stubs(:now).returns(@time)
    end

    it "sets the deleted_at flag in the database" do
      collection.expects(:update).with(
        { :_id => @post.id }, { "$set" => { :deleted_at => @time } }
      ).returns(true)
      @post._remove
    end

    it "sets the deleted flag" do
      collection.expects(:update).with(
        { :_id => @post.id }, { "$set" => { :deleted_at => @time } }
      ).returns(true)
      @post._remove
      @post.destroyed?.should == true
    end
  end

  describe "#_restore" do

    before do
      @post = ParanoidPost.new(:deleted_at => Time.now)
      @post.expects(:collection).returns(collection)
      @time = Time.now
      Time.stubs(:now).returns(@time)
    end

    it "removes the deleted_at flag from the database" do
      collection.expects(:update).with(
        { :_id => @post.id }, { "$unset" => { :deleted_at => true } }
      ).returns(true)
      @post.restore
    end

    it "removes the deleted flag" do
      collection.expects(:update).with(
        { :_id => @post.id }, { "$unset" => { :deleted_at => true } }
      ).returns(true)
      @post.restore
      @post.destroyed?.should == false
    end
  end

  #### Integration Tests ###
  before :all do
    ParanoidPost.delete_all
  end

  context 'a soft deleted item' do
    before :each do
      @post = ParanoidPost.create(:title => 'Can I die more than once?')
      @post.delete
      @post.reload
    end

    after :each do
      @post.destroy!
    end

    it 'should have a deletion date' do
      @post.deleted_at.should_not be_nil
    end

    it 'should be restorable' do
      @post.restore
      @post.reload
      @post.deleted_at.should be_nil
    end

    it 'should be invisible to searches' do
      ParanoidPost.count.should == 0
    end

    it 'should be found overriding default deleted_at scoping' do
      ParanoidPost.where(:deleted_at.ne => nil).count.should == 1
    end

    it 'should be hard-destroyable' do
      @post.destroy!
      ParanoidPost.where(:deleted_at.ne => nil).count.should == 0
    end
  end
end