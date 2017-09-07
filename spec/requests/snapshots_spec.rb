RSpec.describe "Snapshots API" do
  describe "as a subcollection of VMs" do
    describe "GET /api/vms/:c_id/snapshots" do
      it "can list the snapshots of a VM" do
        api_basic_authorize(subcollection_action_identifier(:vms, :snapshots, :read, :get))
        vm = FactoryGirl.create(:vm_vmware)
        snapshot = FactoryGirl.create(:snapshot, :vm_or_template => vm)
        _other_snapshot = FactoryGirl.create(:snapshot)

        run_get(api_vm_snapshots_url(nil, vm))

        expected = {
          "count"     => 2,
          "name"      => "snapshots",
          "subcount"  => 1,
          "resources" => [
            {"href" => api_vm_snapshot_url(nil, vm.compressed_id, snapshot.compressed_id)}
          ]
        }
        expect(response.parsed_body).to include(expected)
        expect(response).to have_http_status(:ok)
      end

      it "will not list snapshots unless authorized" do
        api_basic_authorize
        vm = FactoryGirl.create(:vm_vmware)
        FactoryGirl.create(:snapshot, :vm_or_template => vm)

        run_get(api_vm_snapshots_url(nil, vm))

        expect(response).to have_http_status(:forbidden)
      end
    end

    describe "GET /api/vms/:c_id/snapshots/:s_id" do
      it "can show a VM's snapshot" do
        api_basic_authorize(subcollection_action_identifier(:vms, :snapshots, :read, :get))
        vm = FactoryGirl.create(:vm_vmware)
        create_time = Time.zone.parse("2017-01-11T00:00:00Z")
        snapshot = FactoryGirl.create(:snapshot, :vm_or_template => vm, :create_time => create_time)

        run_get(api_vm_snapshot_url(nil, vm, snapshot))

        expected = {
          "create_time"       => create_time.iso8601,
          "href"              => api_vm_snapshot_url(nil, vm.compressed_id, snapshot.compressed_id),
          "id"                => snapshot.compressed_id,
          "vm_or_template_id" => vm.compressed_id
        }
        expect(response.parsed_body).to include(expected)
        expect(response).to have_http_status(:ok)
      end

      it "will not show a snapshot unless authorized" do
        api_basic_authorize
        vm = FactoryGirl.create(:vm_vmware)
        snapshot = FactoryGirl.create(:snapshot, :vm_or_template => vm)

        run_get(api_vm_snapshot_url(nil, vm, snapshot))

        expect(response).to have_http_status(:forbidden)
      end
    end

    describe "POST /api/vms/:c_id/snapshots" do
      it "can queue the creation of a snapshot" do
        api_basic_authorize(subcollection_action_identifier(:vms, :snapshots, :create))
        ems = FactoryGirl.create(:ext_management_system)
        host = FactoryGirl.create(:host, :ext_management_system => ems)
        vm = FactoryGirl.create(:vm_vmware, :name => "Alice's VM", :host => host, :ext_management_system => ems)

        run_post(api_vm_snapshots_url(nil, vm), :name => "Alice's snapshot")

        expected = {
          "results" => [
            a_hash_including(
              "success"   => true,
              "message"   => "Creating snapshot Alice's snapshot for Virtual Machine id:#{vm.id} name:'Alice's VM'",
              "task_id"   => anything,
              "task_href" => a_string_matching(api_tasks_url)
            )
          ]
        }
        expect(response.parsed_body).to include(expected)
        expect(response).to have_http_status(:ok)
      end

      it "renders a failed action response if snapshotting is not supported" do
        api_basic_authorize(subcollection_action_identifier(:vms, :snapshots, :create))
        vm = FactoryGirl.create(:vm_vmware)

        run_post(api_vm_snapshots_url(nil, vm), :name => "Alice's snapsnot")

        expected = {
          "results" => [
            a_hash_including(
              "success" => false,
              "message" => "The VM is not connected to a Host"
            )
          ]
        }
        expect(response.parsed_body).to include(expected)
        expect(response).to have_http_status(:ok)
      end

      it "renders a failed action response if a name is not provided" do
        api_basic_authorize(subcollection_action_identifier(:vms, :snapshots, :create))
        ems = FactoryGirl.create(:ext_management_system)
        host = FactoryGirl.create(:host, :ext_management_system => ems)
        vm = FactoryGirl.create(:vm_vmware, :name => "Alice's VM", :host => host, :ext_management_system => ems)

        run_post(api_vm_snapshots_url(nil, vm), :description => "Alice's snapshot")

        expected = {
          "results" => [
            a_hash_including(
              "success" => false,
              "message" => "Must specify a name for the snapshot"
            )
          ]
        }
        expect(response.parsed_body).to include(expected)
        expect(response).to have_http_status(:ok)
      end

      it "will not create a snapshot unless authorized" do
        api_basic_authorize
        vm = FactoryGirl.create(:vm_vmware)

        run_post(api_vm_snapshots_url(nil, vm), :description => "Alice's snapshot")

        expect(response).to have_http_status(:forbidden)
      end
    end

    describe "POST /api/vms/:c_id/snapshots/:s_id with revert action" do
      it "can queue a VM for reverting to a snapshot" do
        api_basic_authorize(action_identifier(:vms, :revert, :snapshots_subresource_actions))
        ems = FactoryGirl.create(:ext_management_system)
        host = FactoryGirl.create(:host, :ext_management_system => ems)
        vm = FactoryGirl.create(:vm_vmware, :name => "Alice's VM", :host => host, :ext_management_system => ems)
        snapshot = FactoryGirl.create(:snapshot, :name => "Alice's snapshot", :vm_or_template => vm)

        run_post(api_vm_snapshot_url(nil, vm, snapshot), :action => "revert")

        expected = {
          "message"   => "Reverting to snapshot Alice's snapshot for Virtual Machine id:#{vm.id} name:'Alice's VM'",
          "success"   => true,
          "task_href" => a_string_matching(api_tasks_url),
          "task_id"   => anything
        }
        expect(response.parsed_body).to include(expected)
        expect(response).to have_http_status(:ok)
      end

      it "renders a failed action response if reverting is not supported" do
        api_basic_authorize(action_identifier(:vms, :revert, :snapshots_subresource_actions))
        vm = FactoryGirl.create(:vm_vmware)
        snapshot = FactoryGirl.create(:snapshot, :vm_or_template => vm)

        run_post(api_vm_snapshot_url(nil, vm, snapshot), :action => "revert")

        expected = {
          "success" => false,
          "message" => "The VM is not connected to a Host"
        }
        expect(response.parsed_body).to include(expected)
        expect(response).to have_http_status(:ok)
      end

      it "will not revert to a snapshot unless authorized" do
        api_basic_authorize
        vm = FactoryGirl.create(:vm_vmware)
        snapshot = FactoryGirl.create(:snapshot, :vm_or_template => vm)

        run_post(api_vm_snapshot_url(nil, vm, snapshot), :action => "revert")

        expect(response).to have_http_status(:forbidden)
      end
    end

    describe "POST /api/vms/:c_id/snapshots/:s_id with delete action" do
      it "can queue a snapshot for deletion" do
        api_basic_authorize(action_identifier(:vms, :delete, :snapshots_subresource_actions, :delete))
        ems = FactoryGirl.create(:ext_management_system)
        host = FactoryGirl.create(:host, :ext_management_system => ems)
        vm = FactoryGirl.create(:vm_vmware, :name => "Alice's VM", :host => host, :ext_management_system => ems)
        snapshot = FactoryGirl.create(:snapshot, :name => "Alice's snapshot", :vm_or_template => vm)

        run_post(api_vm_snapshot_url(nil, vm, snapshot), :action => "delete")

        expected = {
          "message"   => "Deleting snapshot Alice's snapshot for Virtual Machine id:#{vm.id} name:'Alice's VM'",
          "success"   => true,
          "task_href" => a_string_matching(api_tasks_url),
          "task_id"   => anything
        }
        expect(response.parsed_body).to include(expected)
        expect(response).to have_http_status(:ok)
      end

      it "renders a failed action response if deleting is not supported" do
        api_basic_authorize(action_identifier(:vms, :delete, :snapshots_subresource_actions, :post))
        vm = FactoryGirl.create(:vm_vmware)
        snapshot = FactoryGirl.create(:snapshot, :vm_or_template => vm)

        run_post(api_vm_snapshot_url(nil, vm, snapshot), :action => "delete")

        expected = {
          "success" => false,
          "message" => "The VM is not connected to a Host"
        }
        expect(response.parsed_body).to include(expected)
        expect(response).to have_http_status(:ok)
      end

      it "will not delete a snapshot unless authorized" do
        api_basic_authorize
        vm = FactoryGirl.create(:vm_vmware)
        snapshot = FactoryGirl.create(:snapshot, :vm_or_template => vm)

        run_post(api_vm_snapshot_url(nil, vm, snapshot), :action => "delete")

        expect(response).to have_http_status(:forbidden)
      end

      it "raises a 404 with proper message if the resource isn't found" do
        api_basic_authorize(action_identifier(:vms, :delete, :snapshots_subresource_actions, :post))
        vm = FactoryGirl.create(:vm_vmware)

        run_post(api_vm_snapshot_url(nil, vm, 0), :action => "delete")

        expected = {
          "error" => a_hash_including(
            "kind"    => "not_found",
            "message" => "Couldn't find Snapshot with 'id'=0",
            "klass"   => "ActiveRecord::RecordNotFound"
          )
        }
        expect(response.parsed_body).to include(expected)
        expect(response).to have_http_status(:not_found)
      end
    end

    describe "POST /api/vms/:c_id/snapshots with delete action" do
      it "can queue multiple snapshots for deletion" do
        api_basic_authorize(action_identifier(:vms, :delete, :snapshots_subcollection_actions, :post))
        ems = FactoryGirl.create(:ext_management_system)
        host = FactoryGirl.create(:host, :ext_management_system => ems)
        vm = FactoryGirl.create(:vm_vmware, :name => "Alice and Bob's VM", :host => host, :ext_management_system => ems)
        snapshot1 = FactoryGirl.create(:snapshot, :name => "Alice's snapshot", :vm_or_template => vm)
        snapshot2 = FactoryGirl.create(:snapshot, :name => "Bob's snapshot", :vm_or_template => vm)

        run_post(
          api_vm_snapshots_url(nil, vm),
          :action    => "delete",
          :resources => [
            {:href => api_vm_snapshot_url(nil, vm, snapshot1)},
            {:href => api_vm_snapshot_url(nil, vm, snapshot2)}
          ]
        )

        expected = {
          "results" => a_collection_containing_exactly(
            a_hash_including(
              "message"   => "Deleting snapshot Alice's snapshot for Virtual Machine id:#{vm.id} name:'Alice and Bob's VM'",
              "success"   => true,
              "task_href" => a_string_matching(api_tasks_url),
              "task_id"   => anything
            ),
            a_hash_including(
              "message"   => "Deleting snapshot Bob's snapshot for Virtual Machine id:#{vm.id} name:'Alice and Bob's VM'",
              "success"   => true,
              "task_href" => a_string_matching(api_tasks_url),
              "task_id"   => anything
            )
          )
        }
        expect(response.parsed_body).to include(expected)
        expect(response).to have_http_status(:ok)
      end

      it "raises a 404 with proper message if a resource isn't found" do
        api_basic_authorize(action_identifier(:vms, :delete, :snapshots_subcollection_actions, :post))
        vm = FactoryGirl.create(:vm_vmware)

        run_post(
          api_vm_snapshots_url(nil, vm),
          :action    => "delete",
          :resources => [
            {:href => api_vm_snapshot_url(nil, vm, 0)}
          ]
        )

        expected = {
          "error" => a_hash_including(
            "kind"    => "not_found",
            "message" => "Couldn't find Snapshot with 'id'=0",
            "klass"   => "ActiveRecord::RecordNotFound"
          )
        }
        expect(response.parsed_body).to include(expected)
        expect(response).to have_http_status(:not_found)
      end
    end

    describe "DELETE /api/vms/:c_id/snapshots/:s_id" do
      it "can delete a snapshot" do
        api_basic_authorize(action_identifier(:vms, :delete, :snapshots_subresource_actions, :delete))
        vm = FactoryGirl.create(:vm_vmware)
        snapshot = FactoryGirl.create(:snapshot, :vm_or_template => vm)

        run_delete(api_vm_snapshot_url(nil, vm, snapshot))

        expect(response).to have_http_status(:no_content)
      end

      it "will not delete a snapshot unless authorized" do
        api_basic_authorize
        vm = FactoryGirl.create(:vm_vmware)
        snapshot = FactoryGirl.create(:snapshot, :vm_or_template => vm)

        run_delete(api_vm_snapshot_url(nil, vm, snapshot))

        expect(response).to have_http_status(:forbidden)
      end

      it "raises a 404 with proper message if the resource isn't found" do
        api_basic_authorize(action_identifier(:vms, :delete, :snapshots_subresource_actions, :delete))
        vm = FactoryGirl.create(:vm_vmware)

        run_delete(api_vm_snapshot_url(nil, vm, 0), :action => "delete")

        expected = {
          "error" => a_hash_including(
            "kind"    => "not_found",
            "message" => "Couldn't find Snapshot with 'id'=0",
            "klass"   => "ActiveRecord::RecordNotFound"
          )
        }
        expect(response.parsed_body).to include(expected)
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "as a subcollection of instances" do
    describe "GET /api/instances/:c_id/snapshots" do
      it "can list the snapshots of an Instance" do
        api_basic_authorize(subcollection_action_identifier(:instances, :snapshots, :read, :get))
        instance = FactoryGirl.create(:vm_openstack)
        snapshot = FactoryGirl.create(:snapshot, :vm_or_template => instance)
        _other_snapshot = FactoryGirl.create(:snapshot)

        run_get(api_instance_snapshots_url(nil, instance))

        expected = {
          "count"     => 2,
          "name"      => "snapshots",
          "subcount"  => 1,
          "resources" => [
            {"href" => api_instance_snapshot_url(nil, instance.compressed_id, snapshot.compressed_id)}
          ]
        }
        expect(response.parsed_body).to include(expected)
        expect(response).to have_http_status(:ok)
      end

      it "will not list snapshots unless authorized" do
        api_basic_authorize
        instance = FactoryGirl.create(:vm_openstack)
        _snapshot = FactoryGirl.create(:snapshot, :vm_or_template => instance)

        run_get(api_instance_snapshots_url(nil, instance))

        expect(response).to have_http_status(:forbidden)
      end
    end

    describe "GET /api/instances/:c_id/snapshots/:s_id" do
      it "can show an Instance's snapshot" do
        api_basic_authorize(subcollection_action_identifier(:instances, :snapshots, :read, :get))
        instance = FactoryGirl.create(:vm_openstack)
        create_time = Time.zone.parse("2017-01-11T00:00:00Z")
        snapshot = FactoryGirl.create(:snapshot, :vm_or_template => instance, :create_time => create_time)

        run_get(api_instance_snapshot_url(nil, instance, snapshot))

        expected = {
          "create_time"       => create_time.iso8601,
          "href"              => api_instance_snapshot_url(nil, instance.compressed_id, snapshot.compressed_id),
          "id"                => snapshot.compressed_id,
          "vm_or_template_id" => instance.compressed_id
        }
        expect(response.parsed_body).to include(expected)
        expect(response).to have_http_status(:ok)
      end

      it "will not show a snapshot unless authorized" do
        api_basic_authorize
        instance = FactoryGirl.create(:vm_openstack)
        snapshot = FactoryGirl.create(:snapshot, :vm_or_template => instance)

        run_get(api_instance_snapshot_url(nil, instance, snapshot))

        expect(response).to have_http_status(:forbidden)
      end
    end

    describe "POST /api/instances/:c_id/snapshots" do
      it "can queue the creation of a snapshot" do
        api_basic_authorize(subcollection_action_identifier(:instances, :snapshots, :create))
        ems = FactoryGirl.create(:ems_openstack_infra)
        host = FactoryGirl.create(:host_openstack_infra, :ext_management_system => ems)
        instance = FactoryGirl.create(:vm_openstack, :name => "Alice's Instance", :ext_management_system => ems, :host => host)

        run_post(api_instance_snapshots_url(nil, instance), :name => "Alice's snapshot")

        expected = {
          "results" => [
            a_hash_including(
              "success"   => true,
              "message"   => "Creating snapshot Alice's snapshot for Instance id:#{instance.id} name:'Alice's Instance'",
              "task_id"   => anything,
              "task_href" => a_string_matching(api_tasks_url)
            )
          ]
        }
        expect(response.parsed_body).to include(expected)
        expect(response).to have_http_status(:ok)
      end

      it "renders a failed action response if snapshotting is not supported" do
        api_basic_authorize(subcollection_action_identifier(:instances, :snapshots, :create))
        instance = FactoryGirl.create(:vm_openstack)

        run_post(api_instance_snapshots_url(nil, instance), :name => "Alice's snapsnot")

        expected = {
          "results" => [
            a_hash_including(
              "success" => false,
              "message" => "The VM is not connected to an active Provider"
            )
          ]
        }
        expect(response.parsed_body).to include(expected)
        expect(response).to have_http_status(:ok)
      end

      it "renders a failed action response if a name is not provided" do
        api_basic_authorize(subcollection_action_identifier(:instances, :snapshots, :create))
        ems = FactoryGirl.create(:ems_openstack_infra)
        host = FactoryGirl.create(:host_openstack_infra, :ext_management_system => ems)
        instance = FactoryGirl.create(:vm_openstack, :name => "Alice's Instance", :ext_management_system => ems, :host => host)

        run_post(api_instance_snapshots_url(nil, instance), :description => "Alice's snapshot")

        expected = {
          "results" => [
            a_hash_including(
              "success" => false,
              "message" => "Must specify a name for the snapshot"
            )
          ]
        }
        expect(response.parsed_body).to include(expected)
        expect(response).to have_http_status(:ok)
      end

      it "will not create a snapshot unless authorized" do
        api_basic_authorize
        instance = FactoryGirl.create(:vm_openstack)

        run_post(api_instance_snapshots_url(nil, instance), :description => "Alice's snapshot")

        expect(response).to have_http_status(:forbidden)
      end
    end

    describe "POST /api/instances/:c_id/snapshots/:s_id with delete action" do
      it "can queue a snapshot for deletion" do
        api_basic_authorize(action_identifier(:instances, :delete, :snapshots_subresource_actions, :delete))

        ems = FactoryGirl.create(:ems_openstack_infra)
        host = FactoryGirl.create(:host_openstack_infra, :ext_management_system => ems)
        instance = FactoryGirl.create(:vm_openstack, :name => "Alice's Instance", :ext_management_system => ems, :host => host)
        snapshot = FactoryGirl.create(:snapshot, :name => "Alice's snapshot", :vm_or_template => instance)

        run_post(api_instance_snapshot_url(nil, instance, snapshot), :action => "delete")

        expected = {
          "message"   => "Deleting snapshot Alice's snapshot for Instance id:#{instance.id} name:'Alice's Instance'",
          "success"   => true,
          "task_href" => a_string_matching(api_tasks_url),
          "task_id"   => anything
        }
        expect(response.parsed_body).to include(expected)
        expect(response).to have_http_status(:ok)
      end

      it "renders a failed action response if deleting is not supported" do
        api_basic_authorize(action_identifier(:instances, :delete, :snapshots_subresource_actions, :post))
        instance = FactoryGirl.create(:vm_openstack)
        snapshot = FactoryGirl.create(:snapshot, :vm_or_template => instance)

        run_post(api_instance_snapshot_url(nil, instance, snapshot), :action => "delete")

        expected = {
          "success" => false,
          "message" => "The VM is not connected to an active Provider"
        }
        expect(response.parsed_body).to include(expected)
        expect(response).to have_http_status(:ok)
      end

      it "will not delete a snapshot unless authorized" do
        api_basic_authorize
        instance = FactoryGirl.create(:vm_openstack)
        snapshot = FactoryGirl.create(:snapshot, :vm_or_template => instance)

        run_post(api_instance_snapshot_url(nil, instance, snapshot), :action => "delete")

        expect(response).to have_http_status(:forbidden)
      end
    end

    describe "POST /api/instances/:c_id/snapshots with delete action" do
      it "can queue multiple snapshots for deletion" do
        api_basic_authorize(action_identifier(:instances, :delete, :snapshots_subresource_actions, :delete))

        ems = FactoryGirl.create(:ems_openstack_infra)
        host = FactoryGirl.create(:host_openstack_infra, :ext_management_system => ems)
        instance = FactoryGirl.create(:vm_openstack, :name => "Alice and Bob's Instance", :ext_management_system => ems, :host => host)
        snapshot1 = FactoryGirl.create(:snapshot, :name => "Alice's snapshot", :vm_or_template => instance)
        snapshot2 = FactoryGirl.create(:snapshot, :name => "Bob's snapshot", :vm_or_template => instance)

        run_post(
          api_instance_snapshots_url(nil, instance),
          :action    => "delete",
          :resources => [
            {:href => api_instance_snapshot_url(nil, instance, snapshot1)},
            {:href => api_instance_snapshot_url(nil, instance, snapshot2)}
          ]
        )

        expected = {
          "results" => a_collection_containing_exactly(
            a_hash_including(
              "message"   => "Deleting snapshot Alice's snapshot for Instance id:#{instance.id} name:'Alice and Bob's Instance'",
              "success"   => true,
              "task_href" => a_string_matching(api_tasks_url),
              "task_id"   => anything
            ),
            a_hash_including(
              "message"   => "Deleting snapshot Bob's snapshot for Instance id:#{instance.id} name:'Alice and Bob's Instance'",
              "success"   => true,
              "task_href" => a_string_matching(api_tasks_url),
              "task_id"   => anything
            )
          )
        }
        expect(response.parsed_body).to include(expected)
        expect(response).to have_http_status(:ok)
      end
    end

    describe "DELETE /api/instances/:c_id/snapshots/:s_id" do
      it "can delete a snapshot" do
        api_basic_authorize(action_identifier(:instances, :delete, :snapshots_subresource_actions, :delete))
        instance = FactoryGirl.create(:vm_openstack)
        snapshot = FactoryGirl.create(:snapshot, :vm_or_template => instance)

        run_delete(api_instance_snapshot_url(nil, instance, snapshot))

        expect(response).to have_http_status(:no_content)
      end

      it "will not delete a snapshot unless authorized" do
        api_basic_authorize
        instance = FactoryGirl.create(:vm_openstack)
        snapshot = FactoryGirl.create(:snapshot, :vm_or_template => instance)

        run_delete(api_instance_snapshot_url(nil, instance, snapshot))

        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
