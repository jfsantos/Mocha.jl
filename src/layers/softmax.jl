############################################################
# Softmax Layer
############################################################
@defstruct SoftmaxLayer Layer (
  name :: String = "softmax",
  (dim :: Int = -2, dim != 0),
  (tops :: Vector{Symbol} = Symbol[], length(tops) > 0),
  (bottoms :: Vector{Symbol} = Symbol[], length(bottoms) == length(tops))
)

type SoftmaxLayerState <: LayerState
  layer :: SoftmaxLayer
  blobs :: Vector{Blob}

  dims  :: Vector{Int}
  etc   :: Any
end

function setup_etc(backend::CPUBackend, layer::SoftmaxLayer, dims::Vector{Int}, data_type, inputs)
  nothing
end

function setup(backend::Backend, layer::SoftmaxLayer, inputs::Vector{Blob}, diffs::Vector{Blob})
  data_type  = eltype(inputs[1])
  blobs      = Blob[make_blob(backend, data_type, size(input)) for input in inputs]
  dims = map(inputs) do input
    total_dim = ndims(input)
    dim = layer.dim < 0 ? layer.dim + total_dim + 1 : layer.dim
    @assert 1 <= dim <= total_dim
    @assert dim != total_dim # should not operate on the mini-batch dimension
    dim
  end

  etc = setup_etc(backend, layer, dims, data_type, inputs)

  state = SoftmaxLayerState(layer, blobs, dims, etc)
  return state
end
function shutdown(backend::CPUBackend, state::SoftmaxLayerState)
  map(destroy, state.blobs)
end

function forward(backend::CPUBackend, state::SoftmaxLayerState, inputs::Vector{Blob})
  for ii = 1:length(inputs)
    input  = inputs[ii].data
    output = state.blobs[ii].data
    op_dim = state.dims[ii]

    dim_pre, dim_prob, dim_post = split_dims(input, op_dim)

    for i = 0:dim_pre-1
      for j = 0:dim_post-1
        idx = Int[i + dim_pre*(k + dim_prob*j) for k=0:dim_prob-1] + 1

        maxval = -Inf
        for k in idx
          @inbounds maxval = max(maxval, input[k])
        end
        for k in idx
          @inbounds output[k] = exp(input[k]-maxval)
        end
        the_sum = 0.0
        for k in idx
          @inbounds the_sum += output[k]
        end
        for k in idx
          @inbounds output[k] /= the_sum
        end
      end
    end
  end
end

function backward(backend::Backend, state::SoftmaxLayerState, inputs::Vector{Blob}, diffs::Vector{Blob})
end

