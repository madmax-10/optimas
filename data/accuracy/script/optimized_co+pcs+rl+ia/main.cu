#include <stdio.h>
#include <stdlib.h>
#include <chrono>
#include <random>
#include <cuda.h>
#include <cub/cub.cuh>
#include <cuda/pipeline>
#include "reference.h"

#define GPU_NUM_THREADS 256
#define TILE_D (GPU_NUM_THREADS * 4)

template <typename T>
__device__ void BlockReduce(T &input) {
  typedef cub::BlockReduce<T, GPU_NUM_THREADS> BlockReduce;
  __shared__ typename BlockReduce::TempStorage temp_storage;
  input = BlockReduce(temp_storage).Sum(input);
}

__global__
void accuracy_kernel(
    const int N,
    const int D,
    const int top_k,
    const float* __restrict__ Xdata,
    const int* __restrict__ labelData,
    int* accuracy)
{

  int local_label;
  float local_label_pred;

  int count = 0;


  __shared__ float s_Xdata_tile_db[3][TILE_D]; // Changed to triple buffer
  cuda::pipeline<cuda::pipeline_shared_state> pipe = cuda::make_pipeline(3); // Pipeline depth 3

  for (int row = blockIdx.x; row < N; row += gridDim.x) {
    if (threadIdx.x == 0) {
      local_label = labelData[row];
      local_label_pred = Xdata[row * D + local_label];
    }

    const int   label      = __shfl_sync(0xFFFFFFFF, local_label, 0);
    const float label_pred = __shfl_sync(0xFFFFFFFF, local_label_pred, 0);

    int ngt = 0;
    const float* row_ptr = Xdata + row * D;

    int current_producer_idx = 0;
    int current_consumer_idx = 0;

    // Initial load 1 (tile 0)
    if (D > 0) {
      cuda::memcpy_async(pipe, s_Xdata_tile_db[current_producer_idx],
                         row_ptr,
                         min(D, (int)TILE_D) * sizeof(float),
                         cuda::group::tiled_partition<GPU_NUM_THREADS>(cuda::this_thread_block()));
      pipe.producer_commit();
      current_producer_idx = (current_producer_idx + 1) % 3;
    }

    // Initial load 2 (tile 1)
    if (D > TILE_D) {
      cuda::memcpy_async(pipe, s_Xdata_tile_db[current_producer_idx],
                         row_ptr + TILE_D,
                         min(D - TILE_D, (int)TILE_D) * sizeof(float),
                         cuda::group::tiled_partition<GPU_NUM_THREADS>(cuda::this_thread_block()));
      pipe.producer_commit();
      current_producer_idx = (current_producer_idx + 1) % 3;
    }

    for (int tile_start_D = 0; tile_start_D < D; tile_start_D += TILE_D) {
      pipe.consumer_wait();
      __syncthreads();

      for (int k = 0; k < TILE_D / blockDim.x; ++k) {
        int col_in_tile = threadIdx.x + k * blockDim.x;
        int global_col = tile_start_D + col_in_tile;

        if (global_col < D) {
          float pred = s_Xdata_tile_db[current_consumer_idx][col_in_tile];
          ngt += (pred > label_pred || (pred == label_pred && global_col <= label));
        }
      }

      // Load next tile (tile_start_D + 2*TILE_D) into the buffer that was just consumed
      if (tile_start_D + 2 * TILE_D < D) {
        cuda::memcpy_async(pipe, s_Xdata_tile_db[current_producer_idx],
                           row_ptr + tile_start_D + 2 * TILE_D,
                           min(D - (tile_start_D + 2 * TILE_D), (int)TILE_D) * sizeof(float),
                           cuda::group::tiled_partition<GPU_NUM_THREADS>(cuda::this_thread_block()));
        pipe.producer_commit();
        current_producer_idx = (current_producer_idx + 1) % 3;
      }
      current_consumer_idx = (current_consumer_idx + 1) % 3;
    }

    pipe.consumer_wait();
    __syncthreads();

    BlockReduce(ngt);
    if (threadIdx.x == 0 && ngt <= top_k) {
      ++count;
    }
  }

  if (threadIdx.x == 0 && count > 0) {
    atomicAdd(accuracy, count);
  }
}


__global__
void accuracy_kernel2(
    const int N,
    const int D,
    const int top_k,
    const float* __restrict__ Xdata,
    const int*   __restrict__ labelData,
    int* accuracy)
{

  int local_label;
  float local_label_pred;

  int count = 0;


  __shared__ float s_Xdata_tile_db[3][TILE_D]; // Changed to triple buffer
  cuda::pipeline<cuda::pipeline_shared_state> pipe = cuda::make_pipeline(3); // Pipeline depth 3

  for (int row = blockIdx.x; row < N; row += gridDim.x) {

    if (threadIdx.x == 0) {
      local_label = labelData[row];
      local_label_pred = Xdata[row * D + local_label];
    }
    const int   label      = __shfl_sync(0xFFFFFFFF, local_label, 0);
    const float label_pred = __shfl_sync(0xFFFFFFFF, local_label_pred, 0);

    int ngt = 0;
    const float* row_ptr = Xdata + row * D;

    int current_producer_idx = 0;
    int current_consumer_idx = 0;

    // Initial load 1 (tile 0)
    if (D > 0) {
      cuda::memcpy_async(pipe, s_Xdata_tile_db[current_producer_idx],
                         row_ptr,
                         min(D, (int)TILE_D) * sizeof(float),
                         cuda::group::tiled_partition<GPU_NUM_THREADS>(cuda::this_thread_block()));
      pipe.producer_commit();
      current_producer_idx = (current_producer_idx + 1) % 3;
    }

    // Initial load 2 (tile 1)
    if (D > TILE_D) {
      cuda::memcpy_async(pipe, s_Xdata_tile_db[current_producer_idx],
                         row_ptr + TILE_D,
                         min(D - TILE_D, (int)TILE_D) * sizeof(float),
                         cuda::group::tiled_partition<GPU_NUM_THREADS>(cuda::this_thread_block()));
      pipe.producer_commit();
      current_producer_idx = (current_producer_idx + 1) % 3;
    }

    for (int tile_start_D = 0; tile_start_D < D; tile_start_D += TILE_D) {
      pipe.consumer_wait();
      __syncthreads();

      for (int k = 0; k < TILE_D / blockDim.x; ++k) {
        int col_in_tile = threadIdx.x + k * blockDim.x;
        int global_col = tile_start_D + col_in_tile;

        if (global_col < D) {
          float pred = s_Xdata_tile_db[current_consumer_idx][col_in_tile];
          ngt += (pred > label_pred || (pred == label_pred && global_col <= label));
        }
      }

      // Load next tile (tile_start_D + 2*TILE_D) into the buffer that was just consumed
      if (tile_start_D + 2 * TILE_D < D) {
        cuda::memcpy_async(pipe, s_Xdata_tile_db[current_producer_idx],
                           row_ptr + tile_start_D + 2 * TILE_D,
                           min(D - (tile_start_D + 2 * TILE_D), (int)TILE_D) * sizeof(float),
                           cuda::group::tiled_partition<GPU_NUM_THREADS>(cuda::this_thread_block()));
        pipe.producer_commit();
        current_producer_idx = (current_producer_idx + 1) % 3;
      }
      current_consumer_idx = (current_consumer_idx + 1) % 3;
    }
    pipe.consumer_wait();
    __syncthreads();

    BlockReduce(ngt);

    if (threadIdx.x == 0 && ngt <= top_k) {
      ++count;
    }
  }

  if (threadIdx.x == 0 && count > 0) {
    atomicAdd(accuracy, count);
  }
}


int main(int argc, char* argv[])
{
  if (argc != 5) {
    printf("Usage: %s <number of rows> <number of columns> <top K> <repeat>\n", argv[0]);
    return 1;
  }
  const int nrows = atoi(argv[1]);
  const int ndims = atoi(argv[2]);
  const int top_k = atoi(argv[3]);
  const int repeat = atoi(argv[4]);

  const int data_size = nrows * ndims;

  const int label_size_bytes = nrows * sizeof(int);
  const size_t data_size_bytes = data_size * sizeof(float);

  int *label = (int*) malloc (label_size_bytes);

  srand(123);
  for (int i = 0; i < nrows; i++)
    label[i] = rand() % ndims;

  float *data = (float*) malloc (data_size_bytes);

  std::default_random_engine g (123);
  std::uniform_real_distribution<float> distr (0.f, 1.f);
  for (int i = 0; i < data_size; i++) {
    data[i] = distr(g);
  }

  int count_ref = reference(nrows, ndims, top_k, data, label);

  int *d_label;
  cudaMalloc((void**)&d_label, label_size_bytes);
  cudaMemcpy(d_label, label, label_size_bytes, cudaMemcpyHostToDevice);

  float *d_data;
  cudaMalloc((void**)&d_data, data_size_bytes);
  cudaMemcpy(d_data, data, data_size_bytes, cudaMemcpyHostToDevice);

  int *d_count;
  cudaMalloc((void**)&d_count, sizeof(int));

  cudaDeviceSynchronize();
  dim3 block (GPU_NUM_THREADS);

  for (int ngrid = nrows / 4; ngrid <= nrows; ngrid += nrows / 4) {

    dim3 grid (ngrid);
    printf("Grid size is %d\n", ngrid);

    auto start = std::chrono::steady_clock::now();

    for (int i = 0; i < repeat; i++) {
      cudaMemset(d_count, 0, sizeof(int));
      accuracy_kernel<<<grid, block>>>(nrows, ndims, top_k, d_data, d_label, d_count);
    }

    cudaDeviceSynchronize();
    auto end = std::chrono::steady_clock::now();
    auto time = std::chrono::duration_cast<std::chrono::nanoseconds>(end - start).count();
    printf("Average execution time of accuracy kernel: %f (us)\n", (time * 1e-3f) / repeat);

    int count;
    cudaMemcpy(&count, d_count, sizeof(int), cudaMemcpyDeviceToHost);
    printf("%s\n", (count == count_ref) ? "PASS" : "FAIL");


    start = std::chrono::steady_clock::now();

    for (int i = 0; i < repeat; i++) {
      cudaMemset(d_count, 0, sizeof(int));
      accuracy_kernel2<<<grid, block>>>(nrows, ndims, top_k, d_data, d_label, d_count);
    }

    cudaDeviceSynchronize();
    end = std::chrono::steady_clock::now();
    time = std::chrono::duration_cast<std::chrono::nanoseconds>(end - start).count();
    printf("Average execution time of accuracy kernel2: %f (us)\n", (time * 1e-3f) / repeat);
    cudaMemcpy(&count, d_count, sizeof(int), cudaMemcpyDeviceToHost);
    printf("%s\n", (count == count_ref) ? "PASS" : "FAIL");
  }

  cudaFree(d_label);
  cudaFree(d_data);
  cudaFree(d_count);

  free(label);
  free(data);

  return 0;
}