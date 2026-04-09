
resource "aws_iam_role" "ec2-role" {
  name               = "ec2-role"
  path               = "/"
  assume_role_policy = data.aws_iam_policy_document.ec2-assume_role.json
}

resource "aws_iam_instance_profile" "ec2-instance-profile" {
  name = "ec2-instance-profile"
  role = aws_iam_role.ec2-role.name
}

resource "aws_iam_role_policy" "ec2-role-policy" {
  name = "ec2-role-policy"
  role = aws_iam_role.ec2-role.id

  policy = data.aws_iam_policy_document.ec2-role-polices.json
}

resource "aws_iam_role_policy_attachment" "ec2-role-policy-ssm" {
  role       = aws_iam_role.ec2-role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}


resource "aws_iam_role" "ec2-role-prometheus" {
  name               = "ec2-role-prometheus"
  path               = "/"
  assume_role_policy = data.aws_iam_policy_document.ec2-assume_role.json
}

resource "aws_iam_instance_profile" "ec2-instance-profile-prometheus" {
  name = "ec2-instance-profile-prometheus"
  role = aws_iam_role.ec2-role-prometheus.name
}

resource "aws_iam_role_policy_attachment" "ec2-role-policy-prometheus" {
  role       = aws_iam_role.ec2-role-prometheus.id
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy" "prometheus-ec2-discovery" {
  name   = "prometheus-ec2-discovery"
  role   = aws_iam_role.ec2-role-prometheus.id
  policy = data.aws_iam_policy_document.prometheus-ec2-discovery.json
} 