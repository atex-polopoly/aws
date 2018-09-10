def _get_autoscaling_client
  @_autoscaling_client ||= Aws::AutoScaling::Client.new
end

def get_autoscaling_group_name(instance_id)
  client = _get_autoscaling_client
  resp = client.describe_auto_scaling_instances({
    instance_ids: [
      instance_id,
    ],
  }).auto_scaling_instances
  abort("Instance with id #{instance_id} is" +
          ' not part of an autoscaling group!') if resp.empty?
  resp[0]['auto_scaling_group_name']
end

def get_desired_capacity(asg_name)
  client = _get_autoscaling_client
  resp = client.describe_auto_scaling_groups({
    auto_scaling_group_names: [
      asg_name,
    ]
  }).auto_scaling_groups
  abort("Autoscaling group with name #{asg_name}" +
          ' was not found!') if resp.empty?
  resp[0]['desired_capacity']
end

def set_desired_capacity(asg_name, desired_capacity)
  client = _get_autoscaling_client
  client.set_desired_capacity({
    auto_scaling_group_name: asg_name,
    desired_capacity: desired_capacity
  })
end

def get_new_instance_id(asg_name)
  client = _get_autoscaling_client

  get_instance_id = lambda { |hash|
    activities = hash['activities']
    return nil if activities.empty?
    message = activities[0]['description']
    vals = message.split ':'
    return nil if vals.length != 2
    vals[1].chomp
  }
  instance_id = _wait_for(get_instance_id) do
    client.describe_scaling_activities({
      auto_scaling_group_name: asg_name,
    })
  end
  puts "Get instance id #{instance_id}"
  instance_id
end

def _wait_for(get_value_lambda, null_value = nil, max_iter = 30, base_sleep = 1)
    iteration = 1
    loop do
      return null_value if iteration == max_iter

      puts "Iteration: #{i}"

      result = yield
      value = get_value_lambda.call(result)

      if value != null_value
        puts "Success:", value
        return value
      end

      puts "Failure ",
      sleep_time = [1 * 2 ** (iteration - 1), 30].min
      puts "Waiting #{sleep_time} s for retry."
      sleep sleep_time
      iteration += 1
    end
end

def get_target_group_health
  target_group_arn = find_target_group_arn instance_id
  client = _get_elb_client
  client.describe_target_health({
    target_group_arn: target_group_arn,
  }).target_health_descriptions
end

def aws_region
  @_aws_az = Net::HTTP.get(URI.parse('http://169.254.169.254/latest/meta-data/placement/availability-zone/')) if @_aws_az.nil?
  # i.e. eu-west-1b -> eu-west-1
  @_aws_az[0..-2]
end

def instance_id
  @_instance_id = Net::HTTP.get(URI.parse('http://169.254.169.254/latest/meta-data/instance-id')) if @_instance_id.nil?
  @_instance_id
end

def scale_in_protect_others(asg)
  client = _get_autoscaling_client
  asgs = client.describe_auto_scaling_groups({
    auto_scaling_group_names: [
      asg,
    ],
  }).auto_scaling_groups

  raise "#{instance_id} belongs in #{asgs.length} auto scaling groups, expected 1!" if asgs.length != 1

  others = asgs[0].instances.select{ |instance| instance.instance_id != instance_id }
  set_instance_protection asg, true, others
end

def set_instance_protection(asg, protected_from_scale_in, *instances)
  client.set_instance_protection({
    auto_scaling_group_name: asg,
    instance_ids: instances,
    protected_from_scale_in: protected_from_scale_in,
  })
end
