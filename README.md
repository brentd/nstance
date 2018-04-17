# Nstance

Nstance is a library for running shell commands inside sandboxed environments, like Docker containers.

## Features

  * **Simple API**: many of the details of managing and connecting to containers have been abstracted away, and a simple event-based asynchronous API is provided for listening to stdout/stderr output, and if the driver supports it, stdin.
  * **Fast** (for its primary use case): Nstance is optimized for running shell commands on premade container images, where the commands may require a few small files or tarballs to be transferred.
  * **Thread safety**: designed with concurrency in mind.
  * **Resource limiting**: Nstance was designed to run shell commands by untrusted users. Options exist to timeout long commands, and limit the amount of output a command may send. Note however that it makes no additional safety guarantees than those of the underlying container platform.
  * **Pluggable drivers**: the default driver uses the Docker Engine API to execute commands. However, Nstance was designed so that drivers could be developed around other container services like Kubernetes.

## Usage

```ruby
# Create a new instance with a Ruby Docker image from DockerHub,
# using the `:docker_attach` driver (the default).
instance = Nstance.create(image: "ruby:alpine", driver: :docker_attach)

# Transfer a file and run a command.
result = instance.run("ruby hello.rb", files: {"hello.rb" => "puts 'Hello World'"})

# The command's exit status.
result.status #=> 0

# Combined log of stdout and stderr.
result.log #=> "hello world\n"

# Calling `stop` is necessary to perform cleanup, like deleting the container.
instance.stop
```

### Asynchronous API

Nstance also includes an asynchronous API. When `run` is called with a block, it returns immediately. The block is yielded an instance of [`Nstance::RunEmitter`](lib/nstance/run_emitter.rb), so you can subscribe to events and do things like stream output to a websocket as it is received.

```ruby
instance = Nstance.create

instance.run("printf 'Hello, the date is: '; date") do |runner|
  # Called when a full line of output is produced
  runner.on_line     { |stream, line| puts "[#{stream}] #{line}" }
  # Called immediately when output is available
  runner.on_chunk    { |stream, chunk| puts "[#{stream}] #{chunk}" }
  # Called when the command completes, whether it terminated successfuly or not.
  runner.on_complete { |result| puts result.status }
end

instance.stop
```

### `run` options

`run(cmd, opts = {}) → Nstance::Result`

`run(cmd, opts = {}) { |emitter| block } → Nstance::RunEmitter`

| Option | Description |
| --- | --- |
| `dir` | The directory to change to before running the command. If not provided, the Docker drivers will use the WORKDIR of the image (often /). |
| `user` | The user to run the command and save files as. If not provided, the Docker drivers will use the USER from the image (often root).|
| `files` | A hash of files in the form `{filepath => contents}`. `filepath` may be relative to `dir` or absolute. Files will be written before the command is run. |
| `archives` | An array of `tar.gz` archive strings to be extracted automatically before the command is run. |
| `timeout` | Length of time in seconds to allow the command to execute before completing the command with a `result.status` of `:timeout`. Default is 10. |
| `output_limit` | Size in bytes the command is allowed to output before being completed with a `result.status` of `:output_limit_exceeded`. The log will be truncated to this length when exceeded. |

## Drivers

### Docker Engine API

Nstance currently ships with support for the [Docker Engine API](https://docs.docker.com/engine/api/), which is suitable for running commands on a single host.

#### Connecting to Docker

By default, Nstance will try to connect to a local Docker daemon via Unix socket. This is perfect for development: if you have a [Docker client](https://www.docker.com/community-edition) installed, it should just work.

In a production environment, it's much safer to connect to a disposable host running nothing but the Docker daemon. Nstance depends on the [docker-api](https://github.com/swipely/docker-api) gem where connection details can be configured via the `Docker` global.

```ruby
Docker.url = ENV["DOCKER_HOST"]
Docker.options = {
  client_cert_data: cert,
  client_key_data: key,
  scheme: "https"
}
```

There are two drivers available that use the Docker Engine API.

#### :docker_attach (the default)

```ruby
instance = Nstance.create(driver: :docker_attach, image: "busybox:latest")
puts instance.run("echo hello")
instance.stop
```

Uses the Docker Engine API's `/containers/:id/attach` endpoint to connect to a single `sh` process. This socket is left open until `stop` is called on the instance, so subsequent runs execute with minimal network overhead.

**Pros**

* Very fast for use cases requiring running many commands on one instance.
* Can differentiate between `stdout` and `stderr` in the output log.
* Less likely to produce zombie containers because Docker's `StdinOnce: true` option is used, which terminates the container automatically when the attached socket closes.

**Cons**

* Does not allocate a TTY, so sending input to `stdin` is not supported.
* Without a TTY, most programs will buffer output, so streaming live output from a command is difficult or impossible.
* Since it attaches to one `sh` process for the duration, calls to `run` are executed serially; only one command can be executed at a time.

#### :docker_exec

```ruby
instance = Nstance.create(driver: :docker_exec, image: "busybox:latest")
puts instance.run("echo hello")
instance.stop
```

Uses the Docker Engine API's `/containers/:id/exec` endpoints to execute each command separately under a new shell.

**Pros**

* Supports sending `stdin` since it allocates a TTY.
* Can run multiple commands concurrently.

**Cons**

* Combines `stdout` and `stderr` in the output log.
* Every command execution is at least two HTTP requests, so there is more network overhead per command than `:docker_attach`.
