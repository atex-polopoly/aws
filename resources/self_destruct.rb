# The maximum time to wait for the initializition of the new server
property :max_wait_time, [Float, Integer], default: 900

resource_name :self_destruct

# Set all other servers in protected from scale in
# Remove scale in protection from self
# Set desired to one less

action :run do

  # require 'aws-sdk'#TODO fix import

  Aws.config[:region] = aws_region

  asg = get_autoscaling_group_name instance_id
  desired = get_desired_capacity asg
  new_desired = desired - 1

  ruby_block 'add scale in protection to other server' do
    block do
      scale_in_protect_others asg
    end
  end

  ruby_block 'remove scale-in protection from self' do
    block do
      set_instance_protection asg, false, instance_id
    end
  end

  scale_down = ruby_block "decrease capacity to #{new_desired}" do
    block do
      set_desired_capacity asg new_desired
    end
  end
end
