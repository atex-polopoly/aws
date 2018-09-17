# The maximum time to wait for the initializition of the new server
property :max_wait_time, [Float, Integer], default: 900

resource_name :scale_up

# Spins up a new AWS ec2-instance in the same autoscaling group as this server is
# located in.
# Waits for the server to successfully deploy before proceeding

action :run do

  Aws.config[:region] = aws_region

  asg_name = get_autoscaling_group_name instance_id
  desired = get_desired_capacity asg_name
  new_desired = desired + 1

  scale_up = ruby_block "increase capacity to #{new_desired}" do
    block do
      current_ids = get_asg_instances asg_name
      set_desired_capacity asg_name, new_desired
      id = get_new_instance_id asg_name, current_ids
      node.default['aws']['created_instance_id'] = id
    end
  end

  wait_for 'initialization of new server' do
    block lambda {
      targets = get_target_group_health
      return false if targets.empty?
      targets.each do |instance|
        next if instance.target.id != node['aws']['created_instance_id']
        puts "#{instance.target.id} #{instance.target_health.state}"
        return instance.target_health.state == 'healthy'
      end
      false
    }
    max_time new_resource.max_wait_time
    only_if { scale_up.updated_by_last_action? }
  end
end
