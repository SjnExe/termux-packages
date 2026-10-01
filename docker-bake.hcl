group "default" {
  targets = ["package-builder", "package-builder-cgct"]
}

target "package-builder" {
  context = "scripts"
  dockerfile = "Dockerfile"
  tags = [
    "termux/package-builder:latest",
    "ghcr.io/termux/package-builder:latest"
  ]
  cache-from = [
    "type=gha,scope=package-builder",
    "type=registry,ref=ghcr.io/termux/package-builder:latest"
  ]
  cache-to = [
    "type=gha,mode=max,scope=package-builder"
  ]
}

target "package-builder-cgct" {
  context = "scripts"
  dockerfile = "Dockerfile.cgct"
  contexts = {
    "ghcr.io/termux/package-builder" = "target:package-builder"
  }
  tags = [
    "termux/package-builder-cgct:latest",
    "ghcr.io/termux/package-builder-cgct:latest"
  ]
  cache-from = [
    "type=gha,scope=package-builder-cgct",
    "type=registry,ref=ghcr.io/termux/package-builder-cgct:latest"
  ]
  cache-to = [
    "type=gha,mode=max,scope=package-builder-cgct"
  ]
}
