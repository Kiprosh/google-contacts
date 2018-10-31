require "spec_helper"

describe GContacts::Element do
  include Support::ResponseMock

  let(:parser) { Nori.new(advanced_typecasting: false) }

  it "changes modifier flags" do
    element = GContacts::Element.new

    element.create
    element.modifier_flag.should == :create

    element.delete
    element.modifier_flag.should == nil

    element.instance_variable_set(:@id, URI("http://google.com/a/b/c"))
    element.update
    element.modifier_flag.should == :update

    element.delete
    element.modifier_flag.should == :delete
  end

  context "converts back to xml" do
    before :each do
      Time.any_instance.stub(:iso8601).and_return("2012-04-06T06:02:04Z")
    end

    it 'with escaping HTML chars' do
      element = GContacts::Element.new('title' => 'Tom & Jerry', 'content' => 'A & B')

      element.create
      xml = element.to_xml(true)

      xml.should =~ %r{<atom:title>Tom &amp; Jerry</atom:title>}
      xml.should =~ %r{<atom:content type='text'>A &amp; B</atom:content>}
    end

    it "with batch used" do
      element = GContacts::Element.new

      element.create
      xml = element.to_xml(true)
      xml.should =~ %r{<batch:id>create</batch:id>}
      xml.should =~ %r{<batch:operation type='insert'/>}

      element.instance_variable_set(:@id, URI("http://google.com/a/b/c"))
      element.update

      xml = element.to_xml(true)
      xml.should =~ %r{<batch:id>update</batch:id>}
      xml.should =~ %r{<batch:operation type='update'/>}

      element.delete
      xml = element.to_xml(true)
      xml.should =~ %r{<batch:id>delete</batch:id>}
      xml.should =~ %r{<batch:operation type='delete'/>}
    end

    it "with deleting an entry" do
      element = GContacts::Element.new(parser.parse(File.read("spec/responses/contacts/get.xml"))["entry"])
      element.delete

      parser.parse(element.to_xml).should == {"atom:entry" => {"id"=>"http://www.google.com/m8/feeds/contacts/john.doe%40gmail.com/full/3a203c8da7ac0a8", "@xmlns:atom"=>"http://www.w3.org/2005/Atom", "@xmlns:gd"=>"http://schemas.google.com/g/2005", "@xmlns:gContact"=>"http://schemas.google.com/contact/2008", "@gd:etag"=>"\"YzllYTBkNmQwOWRlZGY1YWEyYWI5.\""}}
    end

    it "with creating an entry" do
      element = GContacts::Element.new
      element.category = "contact"
      element.content = "Foo Content"
      element.title = "Foo Title"
      element.data = {"gd:name" => {"gd:fullName" => "John Doe", "gd:givenName" => "John", "gd:familyName" => "Doe"}}
      element.create

      parser.parse(element.to_xml).should == {"atom:entry"=>{"atom:category"=>{"@scheme"=>"http://schemas.google.com/g/2005#kind", "@term"=>"http://schemas.google.com/g/2008#contact"}, "atom:content"=>"Foo Content", "atom:title"=>"Foo Title", "gd:name"=>{"gd:fullName"=>"John Doe", "gd:givenName"=>"John", "gd:familyName"=>"Doe"}, "@xmlns:atom"=>"http://www.w3.org/2005/Atom", "@xmlns:gd"=>"http://schemas.google.com/g/2005", "@xmlns:gContact"=>"http://schemas.google.com/contact/2008"}}
    end

    it "updating an entry" do
      element = GContacts::Element.new(parser.parse(File.read("spec/responses/contacts/get.xml"))["entry"])
      element.update

      parser.parse(element.to_xml).should == {"atom:entry"=>{"id"=>"http://www.google.com/m8/feeds/contacts/john.doe%40gmail.com/full/3a203c8da7ac0a8", "atom:category"=>{"@scheme"=>"http://schemas.google.com/g/2005#kind", "@term"=>"http://schemas.google.com/g/2008#contact"}, "atom:content"=>{"@type"=>"text"}, "atom:title"=>"Casey", "gd:name"=>{"gd:fullName"=>"Casey", "gd:givenName"=>"Casey"}, "gd:email"=>[{"@rel"=>"http://schemas.google.com/g/2005#work", "@address"=>"casey@gmail.com", "@primary"=>"true"}, {"@rel"=>"http://schemas.google.com/g/2005#home", "@address"=>"casey.1900@gmail.com"}, {"@rel"=>"http://schemas.google.com/g/2005#home", "@address"=>"casey_case@gmail.com"}], "gd:phoneNumber"=>["3005004000", "+130020003000"], "gd:structuredPostalAddress"=>[{"gd:formattedAddress"=>"Xolo\n      Dome\n      Krypton", "gd:street"=>"Xolo", "gd:city"=>"Dome", "gd:region"=>"Krypton", "@rel"=>"http://schemas.google.com/g/2005#home"}, {"gd:formattedAddress"=>"Nokia Lumia 720\n      Finland\n      Earth", "gd:street"=>"Nokia Limia 720", "gd:city"=>"Finland", "gd:region"=>"Earth", "@rel"=>"http://schemas.google.com/g/2005#work"}], "@xmlns:atom"=>"http://www.w3.org/2005/Atom", "@xmlns:gd"=>"http://schemas.google.com/g/2005", "@xmlns:gContact"=>"http://schemas.google.com/contact/2008", "@gd:etag"=>"\"YzllYTBkNmQwOWRlZGY1YWEyYWI5.\""}}
    end

    it "updating an entry serialized and deserialized" do
      element = GContacts::Element.new(parser.parse(File.read("spec/responses/contacts/get.xml"))["entry"])
      element = YAML::load(YAML::dump(element))
      element.update

      parser.parse(element.to_xml).should == {"atom:entry"=>{"id"=>"http://www.google.com/m8/feeds/contacts/john.doe%40gmail.com/full/3a203c8da7ac0a8", "atom:category"=>{"@scheme"=>"http://schemas.google.com/g/2005#kind", "@term"=>"http://schemas.google.com/g/2008#contact"}, "atom:content"=>{"@type"=>"text"}, "atom:title"=>"Casey", "gd:name"=>{"gd:fullName"=>"Casey", "gd:givenName"=>"Casey"}, "gd:email"=>[{"@rel"=>"http://schemas.google.com/g/2005#work", "@address"=>"casey@gmail.com", "@primary"=>"true"}, {"@rel"=>"http://schemas.google.com/g/2005#home", "@address"=>"casey.1900@gmail.com"}, {"@rel"=>"http://schemas.google.com/g/2005#home", "@address"=>"casey_case@gmail.com"}], "gd:phoneNumber"=>["3005004000", "+130020003000"], "gd:structuredPostalAddress"=>[{"gd:formattedAddress"=>"Xolo\n      Dome\n      Krypton", "gd:street"=>"Xolo", "gd:city"=>"Dome", "gd:region"=>"Krypton", "@rel"=>"http://schemas.google.com/g/2005#home"}, {"gd:formattedAddress"=>"Nokia Lumia 720\n      Finland\n      Earth", "gd:street"=>"Nokia Limia 720", "gd:city"=>"Finland", "gd:region"=>"Earth", "@rel"=>"http://schemas.google.com/g/2005#work"}], "@xmlns:atom"=>"http://www.w3.org/2005/Atom", "@xmlns:gd"=>"http://schemas.google.com/g/2005", "@xmlns:gContact"=>"http://schemas.google.com/contact/2008", "@gd:etag"=>"\"YzllYTBkNmQwOWRlZGY1YWEyYWI5.\""}}
    end

    it "with contacts" do
      elements = GContacts::List.new(parser.parse(File.read("spec/responses/contacts/all.xml")))

      expected = [
        {"id"=>"http://www.google.com/m8/feeds/contacts/john.doe%40gmail.com/full/fd8fb1a55f2916e", "atom:category"=>{"@scheme"=>"http://schemas.google.com/g/2005#kind", "@term"=>"http://schemas.google.com/g/2008#contact"}, "atom:content"=>{"@type"=>"text"}, "atom:title"=>"Steve Stephson", "gd:name"=>{"gd:fullName"=>"Steve Stephson", "gd:givenName"=>"Steve", "gd:familyName"=>"Stephson"}, "gd:email"=>[{"@rel"=>"http://schemas.google.com/g/2005#other", "@address"=>"steve.stephson@gmail.com", "@primary"=>"true"}, {"@rel"=>"http://schemas.google.com/g/2005#other", "@address"=>"steve@gmail.com"}], "gd:phoneNumber"=>["3005004000", "+130020003000", "+130020003111"], "gContact:groupMembershipInfo"=>{"@deleted"=>"false", "@href"=>"http://www.google.com/m8/feeds/groups/john.doe%40gmail.com/base/6"}, "@xmlns:atom"=>"http://www.w3.org/2005/Atom", "@xmlns:gd"=>"http://schemas.google.com/g/2005", "@xmlns:gContact"=>"http://schemas.google.com/contact/2008", "@gd:etag"=>"\"OWUxNWM4MTEzZjEyZTVjZTQ1Mjgy.\""},

        {"id"=>"http://www.google.com/m8/feeds/contacts/john.doe%40gmail.com/full/894bc75ebb5187d", "atom:category"=>{"@scheme"=>"http://schemas.google.com/g/2005#kind", "@term"=>"http://schemas.google.com/g/2008#contact"}, "atom:content"=>{"@type"=>"text"}, "atom:title"=>"Jill Doe", "gd:name"=>{"gd:fullName"=>"Jill Doe", "gd:givenName"=>"Jill", "gd:familyName"=>"Doe"}, "@xmlns:atom"=>"http://www.w3.org/2005/Atom", "@xmlns:gd"=>"http://schemas.google.com/g/2005", "@xmlns:gContact"=>"http://schemas.google.com/contact/2008", "@gd:etag"=>"\"ZGRhYjVhMTNkMmFhNzJjMzEyY2Ux.\""},

        {"id"=>"http://www.google.com/m8/feeds/contacts/john.doe%40gmail.com/full/cd046ed518f0fb0", "atom:category"=>{"@scheme"=>"http://schemas.google.com/g/2005#kind", "@term"=>"http://schemas.google.com/g/2008#contact"}, "atom:content"=>{"@type"=>"text"}, "atom:title"=>"Dave \"Terry\" Pratchett", "gd:name"=>{"gd:fullName"=>"Dave \"Terry\" Pratchett", "gd:givenName"=>"Dave", "gd:additionalName"=>"\"Terry\"", "gd:familyName"=>"Pratchett"}, "gd:organization"=>{"gd:orgName"=>"Foo Bar Inc", "@rel"=>"http://schemas.google.com/g/2005#work"}, "gd:email"=>{"@rel"=>"http://schemas.google.com/g/2005#home", "@address"=>"dave.pratchett@gmail.com", "@primary"=>"true"}, "gd:phoneNumber"=>"7003002000", "gContact:groupMembershipInfo"=>{"@deleted"=>"false", "@href"=>"http://www.google.com/m8/feeds/groups/john.doe%40gmail.com/base/6"}, "@xmlns:atom"=>"http://www.w3.org/2005/Atom", "@xmlns:gd"=>"http://schemas.google.com/g/2005", "@xmlns:gContact"=>"http://schemas.google.com/contact/2008", "@gd:etag"=>"\"ZWVhMDQ0MWI0MWM0YTJkM2MzY2Zh.\""},

        {"id"=>"http://www.google.com/m8/feeds/contacts/john.doe%40gmail.com/full/a1941d3d13cdc66", "atom:category"=>{"@scheme"=>"http://schemas.google.com/g/2005#kind", "@term"=>"http://schemas.google.com/g/2008#contact"}, "atom:content"=>{"@type"=>"text"}, "atom:title"=>"Jane Doe", "gd:name"=>{"gd:fullName"=>"Jane Doe", "gd:givenName"=>"Jane", "gd:familyName"=>"Doe"}, "gd:email"=>{"@rel"=>"http://schemas.google.com/g/2005#home", "@address"=>"jane.doe@gmail.com", "@primary"=>"true"}, "gd:phoneNumber"=>"16004003000", "gd:structuredPostalAddress"=>{"gd:formattedAddress"=>"5 Market St\n        San Francisco\n        CA", "gd:street"=>"5 Market St", "gd:city"=>"San Francisco", "gd:region"=>"CA", "@rel"=>"http://schemas.google.com/g/2005#home"}, "gContact:groupMembershipInfo"=>{"@deleted"=>"false", "@href"=>"http://www.google.com/m8/feeds/groups/john.doe%40gmail.com/base/6"}, "@xmlns:atom"=>"http://www.w3.org/2005/Atom", "@xmlns:gd"=>"http://schemas.google.com/g/2005", "@xmlns:gContact"=>"http://schemas.google.com/contact/2008", "@gd:etag"=>"\"Yzg3MTNiODJlMTRlZjZjN2EyOGRm.\""}
      ]

      elements.each do |element|
        element.category.should == "contact"

        # The extra tags around this are to ensure the test works in JRuby which has a stricter parser
        # and requires the presence of the xlns:#### tags to properly extract data. This isn't an issue with LibXML.

        parser.parse("<feed xmlns='http://www.w3.org/2005/Atom' xmlns:gContact='http://schemas.google.com/contact/2008' xmlns:gd='http://schemas.google.com/g/2005' xmlns:batch='http://schemas.google.com/gdata/batch'>#{element.to_xml}</feed>")["feed"]["atom:entry"].should == expected.shift
      end

      expected.should have(0).items
    end

    it "with groups" do
      elements = GContacts::List.new(parser.parse(File.read("spec/responses/groups/all.xml")))

      expected = [
          {"atom:entry"=>{"id"=>"http://www.google.com/m8/feeds/groups/john.doe%40gmail.com/full/6", "atom:category"=>{"@scheme"=>"http://schemas.google.com/g/2005#kind", "@term"=>"http://schemas.google.com/g/2008#group"}, "atom:content"=>"System Group: My Contacts", "atom:title"=>"System Group: My Contacts", "gContact:systemGroup"=>{"@id"=>"Contacts"}, "@xmlns:atom"=>"http://www.w3.org/2005/Atom", "@xmlns:gd"=>"http://schemas.google.com/g/2005", "@xmlns:gContact"=>"http://schemas.google.com/contact/2008", "@gd:etag"=>"\"YWJmYzA.\""}},

          {"atom:entry"=>{"id"=>"http://www.google.com/m8/feeds/groups/john.doe%40gmail.com/full/ada43d293fdb9b1", "atom:category"=>{"@scheme"=>"http://schemas.google.com/g/2005#kind", "@term"=>"http://schemas.google.com/g/2008#group"}, "atom:content"=>"Misc", "atom:title"=>"Misc", "@xmlns:atom"=>"http://www.w3.org/2005/Atom", "@xmlns:gd"=>"http://schemas.google.com/g/2005", "@xmlns:gContact"=>"http://schemas.google.com/contact/2008", "@gd:etag"=>"\"QXc8cDVSLyt7I2A9WxNTFUkLRQQ.\""}}
      ]

      elements.each do |element|
        element.category.should == "group"
        parser.parse(element.to_xml).should == expected.shift
      end

      expected.should have(0).items
    end
  end

  context 'Check hashed attributes' do
    let(:element) {GContacts::Element.new(parser.parse(File.read("spec/responses/contacts/contact_with_all_data.xml"))["entry"])}

    it '#hashed_email_addresses' do
      element.hashed_email_addresses.should == { "work"=>["casey@gmail.com"], "home"=>["casey.1900@gmail.com", "casey_case@gmail.com"] }
    end

    it '#hashed_addresses' do
      element.hashed_addresses.should == {"home" => [{:address=>"Xolo\n      Dome\n      Krypton", :address_line =>"Xolo", :geo_city=>"Dome", :geo_state=>'Krypton', :zipcode => nil, :country=>"USA"}],
        "work" => [{ :address=>"Nokia Lumia 720\n      Finland\n      Earth", :address_line=>"Nokia Limia 720", :geo_city=>"Finland", :geo_state=>'Earth', :zipcode => nil, :country=>nil}]}
    end

    it '#hashed_phone_numbers' do
      element.hashed_phone_numbers.should == {"Other phone"=>["789-654-3210"], "other_phone"=>["456-654-3210"], "work"=>["3216549870"], "grandcentral"=>["213-654-4645"]}
    end

    it '#hashed_mobile_numbers' do
      element.hashed_mobile_numbers.should == {"Other's mobile"=>["987-654-3210"], "other_mobile"=>["987-456-0213"], "mobile"=>["1234567890"], "work mobile"=>["12321312321213"]}
    end

    it '#hashed_fax_numbers' do
      element.hashed_fax_numbers.should == {"home fax"=>["9999999999"], "work fax"=>["8888888888"], "Other fax"=>["7777777777"], "other_fax"=>["3333333333"]}
    end

    it '#hashed_websites' do
      element.hashed_websites.should == { "profile"=>["example.profile.com"], "blog"=>["example.wordpress.com"],
        "Custom"=>["custom.com"], "home-page"=>["homepage.wordpress.com"], "work"=>["example.work.com"] }
      element.hashed_websites.keys.should == ['profile', 'blog', 'Custom', 'home-page', 'work']
    end
  end

  context 'Aggregate Contact groups' do
    let(:element) { GContacts::Element.new(parser.parse(File.read("spec/responses/contacts/multiple_group.xml"))["entry"]) }
    let(:group)   { element.groups }

    it '#groups' do
      group.count.should == 2
      group.map{ |g| g[:group_href] }.should_not be_empty
      group.map{ |g| g[:group_id] }.should_not be_empty
      group.map{ |g| g[:group_id] }.should include('6', '3d55e0800e9fe827')
    end
  end

  context '#update_groups updates Contact groups' do
    let(:element)         { GContacts::Element.new(parser.parse(File.read("spec/responses/contacts/multiple_group.xml"))["entry"]) }
    let(:new_group)       { 'http://www.google.com/m8/feeds/groups/john.doe%40gmail.com/base/12dsd121as52' }
    let(:updated_element) { parser.parse(File.read("spec/responses/contacts/update_with_group.xml"))["entry"] }

    it 'should return nil if args is empty' do
      element.update_groups().should be_nil
    end

    it 'should remove old groups from a contact' do
      element.groups.count.should == 2
      element.should_receive(:update_groups).with(new_group).once.and_return(updated_element)
      result = element.update_groups(new_group)

      result['gContact:groupMembershipInfo']['@href'].should_not match(/3d55e0800e9fe827/)
    end

    it 'should update with new groups' do
      element.should_receive(:update_groups).with(new_group).once.and_return(updated_element)
      result = element.update_groups(new_group)

      result['gContact:groupMembershipInfo'].should_not be_nil
      result['gContact:groupMembershipInfo']['@deleted'].should == 'false'
      result['gContact:groupMembershipInfo']['@href'].should match(new_group)
    end
  end

  context 'Other attributes' do
    let(:element) { GContacts::Element.new(parser.parse(File.read("spec/responses/contacts/contact_with_all_data.xml"))["entry"]) }

    context '#data should contain other attributes' do
      let!(:data) { element.data }

      it '#birthday' do
        data['gContact:birthday'].should_not be_empty
        data['gContact:birthday'][0].keys.should include("@when")
        data['gContact:birthday'].should include({"@when"=>"1989-09-10"})
      end

      it '#organisation' do
        data['gd:organization'].should_not be_empty
        data['gd:organization'][0].keys.should include('gd:orgName', 'gd:orgTitle')
      end

      it '#websites' do
        data['gContact:website'].should_not be_empty
        data['gContact:website'][0].keys.should include('@href', '@rel')
      end
    end

    context '#birthday' do
      it 'GContacts::Element should have method called birthday' do
        lambda { element.birthday }.should_not raise_error
      end

      it 'should return birthday of a contact' do
        element.birthday.should_not be_nil
        element.birthday.class.should == String
        element.birthday.should == '1989-09-10'
      end

      it 'should return NIL if no birthday is specified' do
        element = GContacts::Element.new
        element.birthday.should be_nil
      end
    end

    context '#organization' do
      let(:entry) { GContacts::Element.new(parser.parse(File.read("spec/responses/contacts/multiple_organization.xml"))["entry"]) }

      it 'GContacts::Element should have method called organization' do
        lambda { entry.organization }.should_not raise_error
      end

      it 'should return organization data of a contact' do
        entry.organization.should_not be_nil
        entry.organization.class.should == Array
        entry.organization.map(&:keys).flatten.should include('gd:orgName', 'gd:orgTitle')
      end

      it 'should return NIL if no organization is specified' do
        entry = GContacts::Element.new
        entry.organization.should be_nil
      end
    end

    context '#org_name' do
      let(:entry) { GContacts::Element.new(parser.parse(File.read("spec/responses/contacts/multiple_organization.xml"))["entry"]) }

      it 'GContacts::Element should have method called org_name' do
        lambda { entry.org_name }.should_not raise_error
      end

      it 'should return primary organization (if present) or first orgName data of a contact' do
        entry.org_name.should_not be_nil
        entry.org_name.should =~ /Primary/
      end

      it 'should return NIL if no organization is specified' do
        entry = GContacts::Element.new
        entry.org_name.should be_nil
      end
    end

    context '#org_title' do
      let(:entry) { GContacts::Element.new(parser.parse(File.read("spec/responses/contacts/multiple_organization.xml"))["entry"]) }

      it 'GContacts::Element should have method called org_title' do
        lambda { entry.org_title }.should_not raise_error
      end

      it 'should return primary organization title (if present) or first orgTitle data of a contact' do
        entry.org_title.should_not be_nil
        entry.org_title.should =~ /True/
      end

      it 'should return NIL if no orgTitle is specified' do
        entry = GContacts::Element.new
        entry.org_title.should be_nil
      end
    end

    context '#websites' do
      it 'GContacts::Element should have method called websites' do
        lambda { element.websites }.should_not raise_error
      end

      it 'should return websites of a contact' do
        websites = element.websites.map { |w| w['gContact:website'] }

        element.websites.should_not be_empty
        websites.should_not be_empty
        websites.should include('example.profile.com', 'example.wordpress.com',
          'custom.com', 'homepage.wordpress.com', 'example.work.com')
      end

      it 'should return empty array if no website is specified' do
        element = GContacts::Element.new
        element.websites.should be_nil
      end
    end
  end
end
