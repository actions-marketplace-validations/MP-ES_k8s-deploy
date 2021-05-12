#
# Step 1
#

# Specify the version of Go to use
FROM golang:1.16 AS builder

# Install upx (upx.github.io) to compress the compiled action
RUN apt-get update && apt-get --no-install-recommends -y install upx &&  rm -rf /var/lib/apt/lists/*

# Disable CGO
ENV CGO_ENABLED=0

# Copy src files from the host into the container
WORKDIR /src
COPY src .

# Compile the action - the added flags instruct Go to produce a
# standalone binary
RUN go build \
  -a \
  -trimpath \
  -ldflags "-s -w -extldflags '-static'" \
  -installsuffix cgo \
  -tags netgo \
  -o /bin/action \
  .

# Strip any symbols - this is not a library
RUN strip /bin/action

# Compress the compiled action
RUN upx -q -9 /bin/action


# Step 2

# Use the most basic and empty container - this container has no
# runtime, files, shell, libraries, etc.
FROM scratch

# Copy over SSL certificates from the first step - this is required
# if our code makes any outbound SSL connections because it contains
# the root CA bundle.
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/

# Copy over the compiled action from the first step
COPY --from=builder /bin/action /bin/action

# Specify the container's entrypoint as the action
ENTRYPOINT ["/bin/action"]