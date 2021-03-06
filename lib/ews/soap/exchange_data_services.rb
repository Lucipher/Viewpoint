module Viewpoint::EWS::SOAP

  # Exchange Data Service operations as listed in the EWS Documentation.
  # @see http://msdn.microsoft.com/en-us/library/bb409286.aspx
  module ExchangeDataServices
    include Viewpoint::EWS::SOAP

    # -------------- Item Operations -------------

    # Identifies items that are located in a specified folder
    # @see http://msdn.microsoft.com/en-us/library/aa566107.aspx
    #
    # @param [Hash] opts
    # @option opts [Array<Hash>] :parent_folder_ids An Array of folder id Hashes, either a
    #   DistinguishedFolderId (must me a Symbol) or a FolderId (String)
    #   [{:id => <myid>, :change_key => <ck>}, {:id => :root}]
    # @option opts [String] :traversal Shallow/Deep/SoftDeleted
    # @option opts [Hash] :item_shape defines the ItemShape node
    # @option item_shape [String] :base_shape IdOnly/Default/AllProperties
    # @option item_shape :additional_properties
    #   See: http://msdn.microsoft.com/en-us/library/aa563810.aspx
    # @option opts [Hash] :calendar_view Limit FindItem by a start and end date
    #   {:calendar_view => {:max_entries_returned => 2, :start_date =>
    #   <DateTime Obj>, :end_date => <DateTime Obj>}}
    # @option opts [Hash] :contacts_view Limit FindItem between contact names
    #   {:contacts_view => {:max_entries_returned => 2, :initial_name => 'Dan',
    #   :final_name => 'Wally'}}
    # @example
    #   { :parent_folder_ids => [{:id => root}],
    #     :traversal => 'Shallow',
    #     :item_shape  => {:base_shape => 'Default'} }
    def find_item(opts)
      opts = opts.clone
      [:parent_folder_ids, :traversal, :item_shape].each do |k|
        validate_param(opts, k, true)
      end
      req = build_soap! do |type, builder|
        if(type == :header)
        else
          builder.nbuild.FindItem(:Traversal => opts[:traversal]) {
            builder.nbuild.parent.default_namespace = @default_ns
            builder.item_shape!(opts[:item_shape])
            # @todo add FractionalPageFolderView
            builder.calendar_view!(opts[:calendar_view]) if opts[:calendar_view]
            builder.contacts_view!(opts[:contacts_view]) if opts[:contacts_view]
            builder.restriction!(opts[:restriction]) if opts[:restriction]
            builder.parent_folder_ids!(opts[:parent_folder_ids])
          }
        end
      end
      do_soap_request(req)
    end

    # Gets items from the Exchange store
    # @see http://msdn.microsoft.com/en-us/library/aa565934(v=EXCHG.140).aspx
    #
    # @param [Hash] opts
    # @option opts [Hash] :item_shape The item shape properties
    #   Ex: {:base_shape => 'Default'}
    # @option opts [Array<Hash>] :item_ids ItemIds Hash. The keys in these Hashes can be
    #   :item_id, :occurrence_item_id, or :recurring_master_item_id. Please see the
    #   Microsoft docs for more information.
    # @example
    #   opts = {
    #     :item_shape => {:base_shape => 'Default'},
    #     :item_ids   => [
    #       {:item_id => {:id => 'id1'}},
    #       {:occurrence_item_id => {:recurring_master_id => 'rid1', :change_key => 'ck', :instance_index => 1}},
    #       {:recurring_master_item_id => {:occurrence_id => 'oid1', :change_key => 'ck'}}
    #       ]}
    def get_item(opts)
      opts = opts.clone
      [:item_shape, :item_ids].each do |k|
        validate_param(opts, k, true)
      end
      req = build_soap! do |type, builder|
        if(type == :header)
        else
          builder.nbuild.GetItem {
            builder.nbuild.parent.default_namespace = @default_ns
            builder.item_shape!(opts[:item_shape])
            builder.item_ids!(opts[:item_ids])
          }
        end
      end
      do_soap_request(req)
    end

    # Defines a request to create an item in the Exchange store.
    # @see http://msdn.microsoft.com/en-us/library/aa565209(v=EXCHG.140).aspx
    #
    # @param [Hash] opts
    # @option opts [String] :message_disposition How the item will be handled after it is created.
    #   Only applicable for to e-mail. Must be one of 'SaveOnly', 'SendOnly', or 'SendAndSaveCopy'
    # @option opts [String] :send_meeting_invitations How meeting requests are handled after they
    #   are created. Required for calendar items. Must be one of 'SendToNone', 'SendOnlyToAll',
    #   'SendToAllAndSaveCopy'
    # @option opts [Hash] :saved_item_folder_id A well formatted folder_id Hash. Ex: {:id => :inbox}
    #   Will on work if 'SendOnly' is specified for :message_disposition
    # @option opts [Array<Hash>] :items This is a complex Hash that conforms to various Item types.
    #   Please see the Microsoft documentation for this element.
    # @example
    #   opts = { 
    #     message_disposition: 'SendAndSaveCopy',
    #     items: [ {message:
    #       {subject: 'test2',
    #        body: {body_type: 'Text', text: 'this is a test'},
    #        to_recipients: [{mailbox: {email_address: 'dan.wanek@gmail.com'}}]
    #       }
    #     }]}
    #
    #   opts = {
    #     send_meeting_invitations: 'SendToAllAndSaveCopy',
    #     items: [ {calendar_item:
    #       {subject: 'test cal item',
    #        body: {body_type: 'Text', text: 'this is a test cal item'},
    #        start: {text: Chronic.parse('tomorrow at 4pm').to_datetime.to_s},
    #        end: {text: Chronic.parse('tomorrow at 5pm').to_datetime.to_s},
    #        required_attendees: [
    #         {attendee: {mailbox: {email_address: 'dan.wanek@gmail.com'}}},
    #        ]
    #       }
    #     }]
    def create_item(opts)
      opts = opts.clone
      [:items].each do |k|
        validate_param(opts, k, true)
      end
      req = build_soap! do |type, builder|
        attribs = {}
        attribs['MessageDisposition'] = opts[:message_disposition] if opts[:message_disposition]
        attribs['SendMeetingInvitations'] = opts[:send_meeting_invitations] if opts[:send_meeting_invitations]
        if(type == :header)
        else
          builder.nbuild.CreateItem(attribs) {
            builder.nbuild.parent.default_namespace = @default_ns
            builder.saved_item_folder_id!(opts[:saved_item_folder_id]) if opts[:saved_item_folder_id]
            builder.nbuild.Items {
              opts[:items].each {|i|
              # The key can be any number of item types like :message,
              #   :calendar, etc
              ikey = i.keys.first
              builder.send("#{ikey}!",i[ikey])
            }
            }
          }
        end
      end
      do_soap_request(req)
    end

    # Used to modify the properties of an existing item in the Exchange store
    # @see http://msdn.microsoft.com/en-us/library/aa581084(v=exchg.140).aspx
    #
    # @param [Hash] opts
    # @option opts [String] :conflict_resolution Identifies the type of conflict resolution to
    #   try during an update. The default value is AutoResolve. Available options are
    #   'NeverOverwrite', 'AutoResolve', 'AlwaysOverwrite'
    # @option opts [String] :message_disposition How the item will be handled after it is updated.
    #   Only applicable for to e-mail. Must be one of 'SaveOnly', 'SendOnly', or 'SendAndSaveCopy'
    # @option opts [String] :send_meeting_invitations_or_cancellations How meeting requests are
    #   handled after they are updated. Required for calendar items. Must be one of 'SendToNone',
    #   'SendOnlyToAll', 'SendOnlyToChanged', 'SendToAllAndSaveCopy', 'SendToChangedAndSaveCopy'
    # @option opts [Hash] :saved_item_folder_id A well formatted folder_id Hash. Ex: {:id => :sentitems}
    #   Will on work if 'SendOnly' is specified for :message_disposition
    # @option opts [Array<Hash>] :item_changes an array of ItemChange elements that identify items
    #   and the updates to apply to the items. See the Microsoft docs for more information.
    # @example
    #   opts = {
    #     :send_meeting_invitations_or_cancellations => 'SendOnlyToChangedAndSaveCopy',
    #     :item_changes => [
    #       { :item_id => {:id => 'id1'},
    #         :updates => [
    #           {:set_item_field => {
    #             :field_uRI => {:field_uRI => 'item:Subject'},
    #             # The following needs to conform to #build_xml! format for now
    #             :calendar_item => { :sub_elements => [{:subject => {:text => 'Test Subject'}}]}
    #           }}
    #         ]
    #       }
    #     ]
    #   }
    def update_item(opts)
      opts = opts.clone
      [:item_changes].each do |k|
        validate_param(opts, k, true)
      end
      req = build_soap! do |type, builder|
        attribs = {}
        attribs['MessageDisposition'] = opts[:message_disposition] if opts[:message_disposition]
        attribs['ConflictResolution'] = opts[:conflict_resolution] if opts[:conflict_resolution]
        attribs['SendMeetingInvitationsOrCancellations'] = opts[:send_meeting_invitations_or_cancellations] if opts[:send_meeting_invitations_or_cancellations]
        if(type == :header)
        else
          builder.nbuild.UpdateItem(attribs) {
            builder.nbuild.parent.default_namespace = @default_ns
            builder.saved_item_folder_id!(opts[:saved_item_folder_id]) if opts[:saved_item_folder_id]
            builder.item_changes!(opts[:item_changes])
          }
        end
      end
      do_soap_request(req)
    end

    # Delete an item from a mailbox in the Exchange store
    # @see http://msdn.microsoft.com/en-us/library/aa580484(v=exchg.140).aspx
    #
    # @param [Hash] opts
    # @option opts [String] :delete_type Describes how an item is deleted. Must be one of
    #   'HardDelete', 'SoftDelete', or 'MoveToDeletedItems'
    # @option opts [String] :send_meeting_cancellations How meetings are handled after they
    #   are deleted. Required for calendar items. Must be one of 'SendToNone', 'SendOnlyToAll',
    #   'SendToAllAndSaveCopy'
    # @option opts [String] :affected_task_occurrences Describes whether a task instance or a
    #   task master is deleted by a DeleteItem Operation. This attribute is required when
    #   tasks are deleted. Must be one of 'AllOccurrences' or 'SpecifiedOccurrenceOnly'
    # @option opts [Array<Hash>] :item_ids ItemIds Hash. The keys in these Hashes can be
    #   :item_id, :occurrence_item_id, or :recurring_master_item_id. Please see the
    #   Microsoft docs for more information.
    # @example
    #   opts = {
    #     :delete_type => 'MoveToDeletedItems',
    #     :item_ids => [{:item_id => {:id => 'id1'}}]
    #     }
    #   inst.delete_item(opts)
    def delete_item(opts)
      opts = opts.clone
      [:delete_type, :item_ids].each do |k|
        validate_param(opts, k, true)
      end
      req = build_soap! do |type, builder|
        attribs = {'DeleteType' => opts[:delete_type]}
        attribs['SendMeetingCancellations'] = opts[:send_meeting_cancellations] if opts[:send_meeting_cancellations]
        attribs['AffectedTaskOccurrences'] = opts[:affected_task_occurrences] if opts[:affected_task_occurrences]
        if(type == :header)
        else
          builder.nbuild.DeleteItem(attribs) {
            builder.nbuild.parent.default_namespace = @default_ns
            builder.item_ids!(opts[:item_ids])
          }
        end
      end
      do_soap_request(req)
    end

    # ------------- Folder Operations ------------

    # Creates folders, calendar folders, contacts folders, tasks folders, and search folders.
    # @see http://msdn.microsoft.com/en-us/library/aa563574.aspx CreateFolder
    #
    # @param [Hash] opts
    # @option opts [Hash] :parent_folder_id A hash with either the name of a
    #   folder or it's numerical ID.
    #   See: http://msdn.microsoft.com/en-us/library/aa565998.aspx 
    #   {:id => :root}  or {:id => 'myfolderid#'}
    # @option opts [Array<Hash>] :folders An array of hashes of folder types
    #   that conform to input for build_xml!
    #   @example [ 
    #     {:folder =>
    #       {:display_name => "New Folder"}},
    #     {:calendar_folder =>
    #       {:folder_id => {:id => 'blah', :change_key => 'blah'}}}
    def create_folder(opts)
      opts = opts.clone
      req = build_soap! do |type, builder|
        if(type == :header)
        else
          builder.nbuild.CreateFolder {|x|
            x.parent.default_namespace = @default_ns
            builder.parent_folder_id!(opts[:parent_folder_id])
            builder.folders!(opts[:folders])
          }
        end
      end
      do_soap_request(req)
    end

    # Defines a request to copy folders in the Exchange store
    # @see http://msdn.microsoft.com/en-us/library/aa563949.aspx
    # @param [Hash] to_folder_id The target FolderId
    #   {:id => <myid>, :change_key => <optional ck>}
    # @param [Array<Hash>] *sources The source Folders
    #   {:id => <myid>, :change_key => <optional_ck>},
    #   {:id => <myid2>, :change_key => <optional_ck>}
    def copy_folder(to_folder_id, *sources)
      req = build_soap! do |type, builder|
        if(type == :header)
        else
          builder.nbuild.CopyFolder {
            builder.nbuild.parent.default_namespace = @default_ns
            builder.to_folder_id!(to_folder_id)
            builder.folder_ids!(sources.flatten)
          }
        end
      end
      do_soap_request(req)
    end

    # Deletes folders from a mailbox.
    # @see http://msdn.microsoft.com/en-us/library/aa564767.aspx DeleteFolder
    #
    # @param [Hash] opts
    # @option opts [Array<Hash>] :folder_ids An array of folder_ids in the form:
    #   [ {:id => 'myfolderID##asdfs', :change_key => 'asdfasdf'},
    #     {:id => :msgfolderroot} ]  # Don't do this for real
    # @option opts [String,nil] :delete_type Type of delete to do:
    #   HardDelete/SoftDelete/MoveToDeletedItems
    # @option opts [String,nil] :act_as User to act on behalf as. This user
    #   must have been given delegate access to this folder or else this
    #   operation will fail.
    def delete_folder(opts)
      req = build_soap! do |type, builder|
        if(type == :header)
        else
          builder.nbuild.DeleteFolder('DeleteType' => opts[:delete_type]) {
            builder.nbuild.parent.default_namespace = @default_ns
            builder.folder_ids!(opts[:folder_ids], opts[:act_as])
          }
        end
      end
      do_soap_request(req)
    end

    # Find subfolders of an identified folder
    # @see http://msdn.microsoft.com/en-us/library/aa563918.aspx
    #
    # @param [Hash] opts
    # @option opts [Array<Hash>] :parent_folder_ids An Array of folder id Hashes,
    #   either a DistinguishedFolderId (must me a Symbol) or a FolderId (String)
    #   [{:id => <myid>, :change_key => <ck>}, {:id => :root}]
    # @option opts [String] :traversal Shallow/Deep/SoftDeleted
    # @option opts [Hash] :folder_shape defines the FolderShape node
    #   See: http://msdn.microsoft.com/en-us/library/aa494311.aspx
    # @option folder_shape [String] :base_shape IdOnly/Default/AllProperties
    # @option folder_shape :additional_properties
    #   See: http://msdn.microsoft.com/en-us/library/aa563810.aspx
    # @option opts [Hash] :restriction A well formatted restriction Hash.
    # @example
    #   { :parent_folder_ids => [{:id => root}],
    #     :traversal => 'Deep',
    #     :folder_shape  => {:base_shape => 'Default'} }
    # @todo add FractionalPageFolderView
    def find_folder(opts)
      opts = opts.clone
      [:parent_folder_ids, :traversal, :folder_shape].each do |k|
        validate_param(opts, k, true)
      end
      req = build_soap! do |type, builder|
        if(type == :header)
        else
          builder.nbuild.FindFolder(:Traversal => opts[:traversal]) {
            builder.nbuild.parent.default_namespace = @default_ns
            builder.folder_shape!(opts[:folder_shape])
            builder.restriction!(opts[:restriction]) if opts[:restriction]
            builder.parent_folder_ids!(opts[:parent_folder_ids])
          }
        end
      end
      do_soap_request(req)
    end

    # Gets folders from the Exchange store
    # @see http://msdn.microsoft.com/en-us/library/aa580274.aspx
    #
    # @param [Hash] opts
    # @option opts [Array<Hash>] :folder_ids An array of folder_ids in the form:
    #   [ {:id => 'myfolderID##asdfs', :change_key => 'asdfasdf'},
    #     {:id => :msgfolderroot} ]
    # @option opts [Hash] :folder_shape defines the FolderShape node
    # @option folder_shape [String] :base_shape IdOnly/Default/AllProperties
    # @option folder_shape :additional_properties
    # @option opts [String,nil] :act_as User to act on behalf as. This user must
    #   have been given delegate access to this folder or else this operation
    #   will fail.
    # @example
    #   { :folder_ids   => [{:id => :msgfolderroot}],
    #     :folder_shape => {:base_shape => 'Default'} }
    def get_folder(opts)
      opts = opts.clone
      [:folder_ids, :folder_shape].each do |k|
        validate_param(opts, k, true)
      end
      validate_param(opts[:folder_shape], :base_shape, true)
      req = build_soap! do |type, builder|
        if(type == :header)
        else
          builder.nbuild.GetFolder {
            builder.nbuild.parent.default_namespace = @default_ns
            builder.folder_shape!(opts[:folder_shape])
            builder.folder_ids!(opts[:folder_ids], opts[:act_as])
          }
        end
      end
      do_soap_request(req)
    end
    
    # Defines a request to move folders in the Exchange store
    # @see http://msdn.microsoft.com/en-us/library/aa566202.aspx
    # @param [Hash] to_folder_id The target FolderId
    #   {:id => <myid>, :change_key => <optional ck>}
    # @param [Array<Hash>] *sources The source Folders
    #   {:id => <myid>, :change_key => <optional_ck>},
    #   {:id => <myid2>, :change_key => <optional_ck>}
    def move_folder(to_folder_id, *sources)
      req = build_soap! do |type, builder|
        if(type == :header)
        else
          builder.nbuild.MoveFolder {
            builder.nbuild.parent.default_namespace = @default_ns
            builder.to_folder_id!(to_folder_id)
            builder.folder_ids!(sources.flatten)
          }
        end
      end
      do_soap_request(req)
    end

    # Update properties for a specified folder
    # There is a lot more building in this method because most of the builders
    # are only used for this operation so there was no need to externalize them
    # for re-use.
    # @see http://msdn.microsoft.com/en-us/library/aa580519(v=EXCHG.140).aspx
    # @param [Array<Hash>] folder_changes an Array of well formatted Hashes
    def update_folder(folder_changes)
      req = build_soap! do |type, builder|
        if(type == :header)
        else
          builder.nbuild.UpdateFolder {
            builder.nbuild.parent.default_namespace = @default_ns
            builder.nbuild.FolderChanges {
              folder_changes.each do |fc|
                builder[NS_EWS_TYPES].FolderChange {
                  builder.dispatch_folder_id!(fc)
                  builder[NS_EWS_TYPES].Updates {
                    # @todo finish implementation
                  }
                }
              end
            }
          }
        end
      end
      do_soap_request(req)
    end

    # Empties folders in a mailbox.
    # @see http://msdn.microsoft.com/en-us/library/ff709484.aspx
    # @param [Hash] opts
    # @option opts [String] :delete_type Must be one of
    #   ExchangeDataServices::HARD_DELETE, SOFT_DELETE, or MOVE_TO_DELETED_ITEMS
    # @option opts [Boolean] :delete_sub_folders
    # @option opts [Array<Hash>] :folder_ids An array of folder_ids in the form:
    #   [ {:id => 'myfolderID##asdfs', :change_key => 'asdfasdf'},
    #     {:id => 'blah'} ]
    # @todo Finish
    def empty_folder(opts)
      validate_version(VERSION_2010_SP1)
      ef_opts = {}
      [:delete_type, :delete_sub_folders].each do |k|
        ef_opts[k.to_s.camel_case] = validate_param(opts, k, true)
      end
      fids = validate_param opts, :folder_ids, true

      req = build_soap! do |type, builder|
        if(type == :header)
        else
          builder.nbuild.EmptyFolder(ef_opts) {|x|
            builder.nbuild.parent.default_namespace = @default_ns
            builder.folder_ids!(fids)
          }
        end
      end
      do_soap_request(req)
    end

    # ----------- Attachment Operations ----------

    # ------------ Utility Operations ------------

    # Exposes the full membership of distribution lists.
    # @see http://msdn.microsoft.com/en-us/library/aa494152.aspx ExpandDL
    #
    # @todo Fully support all of the ExpandDL operations. Today it just supports
    #   taking an e-mail address as an argument
    # @param [Hash] opts
    # @option opts [String] :email_address The e-mail address of the
    #   distribution to resolve
    # @option opts [Hash] :item_id The ItemId of the private distribution to resolve.
    #   {:id => 'my id'}
    def expand_dl(opts)
      opts = opts.clone
      req = build_soap! do |type, builder|
        if(type == :header)
        else
        builder.nbuild.ExpandDL {|x|
          x.parent.default_namespace = @default_ns
          x.Mailbox {|mb|
            key = :email_address
            mb[NS_EWS_TYPES].EmailAddress(opts[key]) if opts[key]
            builder.item_id! if opts[:item_id]
          }
        }
        end
      end
      do_soap_request(req)
    end

    # Resolve ambiguous e-mail addresses and display names
    # @see http://msdn.microsoft.com/en-us/library/aa565329.aspx ResolveNames
    # @see http://msdn.microsoft.com/en-us/library/aa581054.aspx UnresolvedEntry
    # @param [Hash] opts
    # @option opts [String] :name the unresolved entry
    # @option opts [Boolean] :full_contact_data (true) Whether or not to return
    #   the full contact details.
    # @option opts [String] :search_scope where to seach for this entry, one of
    #   SOAP::Contacts, SOAP::ActiveDirectory, SOAP::ActiveDirectoryContacts
    #   (default), SOAP::ContactsActiveDirectory
    # @option opts [String, FolderId] :parent_folder_id either the name of a
    #   folder or it's numerical ID.
    #   @see http://msdn.microsoft.com/en-us/library/aa565998.aspx
    def resolve_names(opts)
      opts = opts.clone
      fcd = opts.has_key?(:full_contact_data) ? opts[:full_contact_data] : true
      req = build_soap! do |type, builder|
        if(type == :header)
        else
        builder.nbuild.ResolveNames {|x|
          x.parent['ReturnFullContactData'] = fcd.to_s
          x.parent['SearchScope'] = opts[:search_scope] if opts[:search_scope]
          x.parent.default_namespace = @default_ns
          # @todo builder.nbuild.ParentFolderIds
          x.UnresolvedEntry(opts[:name])
        }
        end
      end
      do_soap_request(req)
    end

    # Converts item and folder identifiers between formats.
    # @see http://msdn.microsoft.com/en-us/library/bb799665.aspx
    # @todo Needs to be finished
    def convert_id(opts)
      opts = opts.clone
      req = build_soap! do |type, builder|
        if(type == :header)
        else
        builder.nbuild.ConvertId {|x|
        }
        end
      end
      do_soap_request(req)
    end

  end #ExchangeDataServices
end
