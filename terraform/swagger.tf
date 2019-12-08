data "template_file" "swagger_json" {
  template = file("./swagger/swagger.json")
  vars = {
    host   = var.docs_base_url == "NOT_SET" ? "${aws_s3_bucket.main.id}.s3-website.${var.aws_region}.amazonaws.com" : var.docs_base_url
    schema = tobool(lower(var.https)) ? "https" : "http"
  }
}

resource "aws_s3_bucket_object" "swagger_json" {
  bucket = aws_s3_bucket.main.id
  key    = "swagger.json"

  content = data.template_file.swagger_json.rendered
  acl = "public-read"
  content_type = "application/json"

  etag = md5(data.template_file.swagger_json.rendered)
}

resource "aws_s3_bucket_object" "swagger_index" {
  bucket = aws_s3_bucket.main.id
  key    = "index.html"

  source = "./swagger/index.html"
  acl = "public-read"
  content_type = "text/html"

  etag = filemd5("./swagger/index.html")
}

resource "aws_s3_bucket_object" "swagger_css" {
  bucket = aws_s3_bucket.main.id
  key    = "swagger-ui.css"

  source = "./swagger/swagger-ui.css"
  acl = "public-read"
  content_type = "text/css"

  etag = filemd5("./swagger/swagger-ui.css")
}

resource "aws_s3_bucket_object" "swagger_bundle" {
  bucket = aws_s3_bucket.main.id
  key    = "swagger-ui-bundle.js"

  source = "./swagger/swagger-ui-bundle.js"
  acl = "public-read"

  etag = filemd5("./swagger/swagger-ui-bundle.js")
}

resource "aws_s3_bucket_object" "swagger_standalone" {
  bucket = aws_s3_bucket.main.id
  key    = "swagger-ui-standalone-preset.js"

  source = "./swagger/swagger-ui-standalone-preset.js"
  acl = "public-read"

  etag = filemd5("./swagger/swagger-ui-standalone-preset.js")
}