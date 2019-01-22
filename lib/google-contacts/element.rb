require 'net/http'

# GContacts::Element
module GContacts
  class Element
    attr_accessor :addresses, :birthday, :content, :data, :category, :emails,
                  :entry, :etag, :fax_numbers, :groups, :group_id,
                  :hashed_addresses, :hashed_email_addresses,
                  :hashed_fax_numbers, :hashed_phone_numbers,
                  :hashed_mobile_numbers, :hashed_websites, :mobiles, :name,
                  :organization, :org_name, :org_title, :phones, :title,
                  :websites
    attr_reader :batch, :edit_uri, :id, :modifier_flag, :photo_uri, :updated

    ##
    # Creates a new element by parsing the returned entry from Google
    # @param [Hash, Optional] entry Hash representation of the XML
    # returned from Google
    #
    def initialize(entry = nil)
      @data = {}
      return unless entry
      @entry = entry

      @id = entry['id']
      @updated = entry['updated']
      @content = entry['content']
      @title = entry['title']
      @etag = entry['@gd:etag']
      @name = entry['gd:name']
      @organization = entry['gd:organization']

      process_element
      assign_addresses
      assign_category
      assign_email_addresses
      assign_groups
      assign_phone_and_fax_numbers
      assign_photo_uri
      assign_websites
      organize_birthdays(@data['gContact:birthday'])
      organization_details
    end

    ##
    # Converts the entry into XML to be sent to Google
    def to_xml(batch = false)
      xml = "<atom:entry xmlns:atom='http://www.w3.org/2005/Atom'"
      xml << " xmlns:gd='http://schemas.google.com/g/2005'"
      xml << " xmlns:gContact='http://schemas.google.com/contact/2008'"
      xml << " gd:etag='#{@etag}'" if @etag
      xml << ">\n"

      if batch
        xml << "  <batch:id>#{@modifier_flag}</batch:id>\n"
        xml << "  <batch:operation type='#{@modifier_flag == :create ? 'insert' : @modifier_flag}'/>\n"
      end

      # While /base/ is whats returned, /full/ is what it seems to actually want
      xml << "  <id>#{@id.to_s.gsub('/base/', '/full/')}</id>\n" if @id

      unless @modifier_flag == :delete
        xml << "  <atom:category scheme='http://schemas.google.com/g/2005#kind' term='http://schemas.google.com/g/2008##{@category}'/>\n"
        xml << "  <atom:content type='text'>#{CGI.escapeHTML(@content || '')}</atom:content>\n"
        xml << "  <atom:title>#{CGI.escapeHTML(@title || '')}</atom:title>\n"
        xml << "  <gContact:groupMembershipInfo deleted='false' href='#{@group_id}'/>\n" if @group_id

        @data.each do |key, parsed|
          xml << handle_data(key, parsed, 2)
        end
      end

      xml << "</atom:entry>\n"
    end

    ##
    # Flags the element for creation, must be passed through
    # {GContacts::Client#batch} for the change to take affect.
    def create
      @modifier_flag = :create unless @id
    end

    ##
    # Flags the element for deletion, must be passed through
    # {GContacts::Client#batch} for the change to take affect.
    def delete
      @modifier_flag = (:delete if @id)
    end

    ##
    # Flags the element to be updated, must be passed through
    # {GContacts::Client#batch} for the change to take affect.
    def update
      @modifier_flag = :update if @id
    end

    ##
    # Whether {#create}, {#delete} or {#update} have been called
    def has_modifier?
      !!@modifier_flag
    end

    def inspect
      "#<#{self.class.name} title: \"#{@title}\", updated: \"#{@updated}\">"
    end

    alias to_s inspect

    # Update group list
    # usage : element.update_groups(list_of_group_ids)
    #
    def update_groups(*group_links)
      data.delete('gContact:groupMembershipInfo')
      group_links = group_links.flatten
      return if group_links.empty?

      data['gContact:groupMembershipInfo'] = []
      group_links.each do |group_link|
        params = {
          '@deleted' => 'false',
          '@href' => group_link.to_s
        }
        data['gContact:groupMembershipInfo'] << params
      end
    end

    private

    def assign_addresses
      @addresses = []
      nodes = if entry['gd:structuredPostalAddress'].is_a?(Array)
                entry['gd:structuredPostalAddress']
              elsif !entry['gd:structuredPostalAddress'].nil?
                [entry['gd:structuredPostalAddress']]
              else
                []
              end
      nodes.each do |address|
        new_address = {}
        new_address['address']        = address['gd:formattedAddress']
        new_address['address_line']   = address['gd:street']
        new_address['geo_city']       = address['gd:city']
        new_address['geo_state']      = address['gd:region']
        new_address['zipcode']        = address['gd:postcode']
        new_address['address_line_2'] = address['gd:neighborhood']
        new_address['pobox']          = address['gd:pobox']
        country = address['gd:country']
        new_address['country'] =
          case country.class.name
          when 'String', 'Nori::StringWithAttributes'
            country.attributes['code'] || country
          when 'Hash'
            country['@code']
          end
        new_address['type'] = if address['@rel'].nil?
                                address['@label']
                              else
                                get_google_label_name(address['@rel'])
                              end

        @addresses << new_address
      end
      organize_addresses
    end

    def organize_addresses
      @hashed_addresses = {}
      @addresses.each do |address|
        type = address['type']
        @hashed_addresses[type] = [] unless @hashed_addresses[type]
        @hashed_addresses[type] << {
          address:        address['address'],
          address_line:   address['address_line'],
          geo_city:       address['geo_city'],
          geo_state:      address['geo_state'],
          zipcode:        address['zipcode'],
          country:        address['country'],
          address_line_2: address['address_line_2'],
          pobox:          address['pobox']
        }
      end
    end

    def assign_category
      return unless entry['category']
      @category = entry['category']['@term'].split('#', 2).last
      @category_tag = entry['category']['@label'] if entry['category']['@label']
    end

    def assign_email_addresses
      @emails = []
      nodes = if entry['gd:email'].is_a?(Array)
                entry['gd:email']
              elsif !entry['gd:email'].nil?
                [entry['gd:email']]
              else
                []
              end

      nodes.each do |email|
        new_email = {}
        new_email['address'] = email['@address']
        new_email['type'] = if email['@rel'].nil?
                              email['@label']
                            else
                              get_google_label_name(email['@rel'])
                            end

        @emails << new_email
      end
      organize_emails
    end

    def organize_emails
      @hashed_email_addresses = {}
      @emails.each do |email|
        type = email['type']
        text = email['address']
        @hashed_email_addresses[type] = [] unless @hashed_email_addresses[type]
        @hashed_email_addresses[type] << text
      end
    end

    def assign_groups
      @groups = []
      groups = [entry['gContact:groupMembershipInfo']]
      return unless groups
      groups.flatten.compact.each do |group|
        @modifier_flag = :delete if group['@deleted'] == 'true'
        @groups << {
          group_id: group['@href'].split('/').pop,
          group_href: group['@href']
        }
      end
    end

    def assign_phone_and_fax_numbers
      @phones = []
      @mobiles = []
      @fax_numbers = []
      nodes = if entry['gd:phoneNumber'].is_a?(Array)
                entry['gd:phoneNumber']
              elsif !entry['gd:phoneNumber'].nil?
                [entry['gd:phoneNumber']]
              else
                []
              end

      nodes.each do |phone|
        next unless phone.respond_to? :attributes
        new_phone = {}
        new_phone['text'] = phone
        google_category = if phone.attributes['rel'].nil?
                            phone.attributes['label']
                          else
                            get_google_label_name(phone.attributes['rel'])
                          end

        new_phone['@rel'] = google_category
        if google_category.downcase.include?('mobile')
          @mobiles << new_phone
        elsif google_category.downcase.include?('fax')
          @fax_numbers << new_phone
        else
          @phones << new_phone
        end
      end
      organize_phone_numbers
      organize_mobile_numbers
      organize_fax_numbers
    end

    def assign_photo_uri
      @photo_uri = nil
      # Need to know where to send the update request
      if entry['link'].is_a?(Array)
        entry['link'].each do |link|
          if link['@rel'] == 'edit'
            @edit_uri = URI(link['@href'])
          elsif link['@rel'].match(/rel#photo$/) && !link['@gd:etag'].nil?
            @photo_uri = URI(link['@href'])
          end
        end
      end
    end

    def organize_phone_numbers
      @hashed_phone_numbers = {}
      @phones.each do |phone|
        type = phone['@rel']
        text = phone['text']
        @hashed_phone_numbers[type] = [] unless @hashed_phone_numbers[type]
        @hashed_phone_numbers[type] << text
      end
    end

    def organize_mobile_numbers
      @hashed_mobile_numbers = {}
      @mobiles.each do |mobile|
        type = mobile['@rel']
        text = mobile['text']
        @hashed_mobile_numbers[type] = [] unless @hashed_mobile_numbers[type]
        @hashed_mobile_numbers[type] << text
      end
    end

    def organize_fax_numbers
      @hashed_fax_numbers = {}
      @fax_numbers.each do |fax|
        type = fax['@rel']
        text = fax['text']
        @hashed_fax_numbers[type] = [] unless @hashed_fax_numbers[type]
        @hashed_fax_numbers[type] << text
      end
    end

    def assign_websites
      @websites = []
      nodes = if entry['gContact:website'].is_a?(Array)
                entry['gContact:website']
              elsif !entry['gContact:website'].nil?
                [entry['gContact:website']]
              else
                []
              end

      nodes.each do |website|
        new_website = {}
        new_website['gContact:website'] = website['@href']
        new_website['type'] =
          if website['@rel'].nil?
            website['@label']
          else
            website['@rel']
          end
        @websites << new_website
      end
      organize_websites
    end

    def get_google_label_name(google_type)
      google_type.split('#').last.tr('_', ' ')
    end

    def handle_data(tag, data, indent)
      if data.is_a?(Array)
        xml = ''
        data.each do |value|
          xml << write_tag(tag, value, indent)
        end
      else
        xml = write_tag(tag, data, indent)
      end

      xml
    end

    def organize_birthdays(primary_birthday)
      primary_birthday.blank? && return
      @birthday = primary_birthday.first['@when']
    end

    def organization_details
      @organization.blank? && return

      org_details = if @organization.is_a?(Array)
                      @organization.select { |k| k['@primary'] }.first ||
                        @organization.first
                    else
                      @organization
                    end
      @org_name  = org_details['gd:orgName']
      @org_title = org_details['gd:orgTitle']
    end

    def organize_websites
      @hashed_websites = {}
      @websites.each do |website|
        href = website['gContact:website']
        type = website['type']
        @hashed_websites[type] = [] unless @hashed_websites[type]
        @hashed_websites[type] << href
      end
    end

    # Parse out all the relevant data
    def process_element
      entry.each do |key, unparsed|
        if key =~ /^(gd:|gContact:)/
          @data[key] = if unparsed.is_a?(Array)
                         unparsed.map { |v| parse_element(v) }
                       else
                         [parse_element(unparsed)]
                       end
        elsif key =~ /^batch:(.+)/
          @batch ||= {}

          if Regexp.last_match(1) == 'interrupted'
            @batch['status'] = 'interrupted'
            @batch['code'] = '400'
            @batch['reason'] = unparsed['@reason']
            @batch['status'] = {
              'parsed' => unparsed['@parsed'].to_i,
              'success' => unparsed['@success'].to_i,
              'error' => unparsed['@error'].to_i,
              'unprocessed' => unparsed['@unprocessed'].to_i
            }
          elsif Regexp.last_match(1) == 'id'
            @batch['status'] = unparsed
          elsif Regexp.last_match(1) == 'status'
            if unparsed.is_a?(Hash)
              @batch['code'] = unparsed['@code']
              @batch['reason'] = unparsed['@reason']
            else
              @batch['code'] = unparsed.attributes['code']
              @batch['reason'] = unparsed.attributes['reason']
            end

          elsif Regexp.last_match(1) == 'operation'
            @batch['operation'] = unparsed['@type']
          end
        end
      end
    end

    def parse_element(unparsed)
      data = {}

      if unparsed.is_a?(Hash)
        data = unparsed
      elsif unparsed.is_a?(Nori::StringWithAttributes)
        data['text'] = unparsed.to_s
        unparsed.attributes.each { |k, v| data["@#{k}"] = v }
      end

      data
    end

    def write_tag(tag, data, indent)
      xml = ' ' * indent
      xml << '<' << tag

      # Need to check for any additional attributes to
      # attach since they can be mixed in
      misc_keys = 0
      if data.is_a?(Hash)
        misc_keys = data.length

        data.each do |key, value|
          next unless key =~ /^@(.+)/
          xml << " #{Regexp.last_match(1)}=#{value.is_a?(String) ? value.encode(xml: :attr) : value}"
          misc_keys -= 1
        end

        # We explicitly converted the Nori::StringWithAttributes to a hash
        data = data['text'] if data['text'] && (misc_keys == 1)

      # Nothing to filter out so we can just toss them on
      elsif data.is_a?(Nori::StringWithAttributes)
        data.attributes.each { |k, v| xml << " #{k}='#{v}'" }
      end

      # Just a string, can add it and exit quickly
      if !data.is_a?(Array) && !data.is_a?(Hash)
        xml << '>'
        xml << CGI.escapeHTML(data.to_s)
        xml << "</#{tag}>\n"
        return xml
      # No other data to show, was just attributes
      elsif misc_keys.zero?
        xml << "/>\n"
        return xml
      end

      # Otherwise we have some recursion to do
      xml << ">\n"

      data.each do |key, value|
        next if key =~ /^@/
        xml << handle_data(key, value, indent + 2)
      end

      xml << ' ' * indent
      xml << "</#{tag}>\n"
    end
  end
end
