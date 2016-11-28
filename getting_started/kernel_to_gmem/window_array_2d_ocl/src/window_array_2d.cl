/*******************************************************************************
Copyright (c) 2016, Xilinx, Inc.
All rights reserved.
 
Redistribution and use in source and binary forms, with or without modification,
are permitted provided that the following conditions are met:
 
1. Redistributions of source code must retain the above copyright notice,
this list of conditions and the following disclaimer.
 
 
2. Redistributions in binary form must reproduce the above copyright notice,
this list of conditions and the following disclaimer in the documentation
and/or other materials provided with the distribution.
 
 
3. Neither the name of the copyright holder nor the names of its contributors
may be used to endorse or promote products derived from this software
without specific prior written permission.
 
 
THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,THE IMPLIED 
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, 
INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, 
BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, 
DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY 
OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING 
NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE,
EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

*******************************************************************************/

/*******************************************************************************
Description: 
OpenCL Kernel Example using AXI4-master interface to access window of data from 2D array
*******************************************************************************/
    			      
//Includes 
#include "host.h"

//Declaring PIPE memory with Depth 16
pipe int inFifo __attribute__((xcl_reqd_pipe_depth(16)));
pipe int outFifo __attribute__((xcl_reqd_pipe_depth(16)));

// Read data Kernel : Read tile/window of Data from Global Memory
kernel __attribute__ ((reqd_work_group_size(1, 1, 1)))
void read_data(__global int *inx) {
    int tile[TILE_HEIGHT][WORD_GROUP_SIZE];
    rd_loop_i: for(int i = 0; i < TILE_PER_COLUMN; ++i) {
        rd_loop_j: for (int j = 0; j < WORD_GROUP_PER_ROW; ++j) {
            rd_buf_loop_m: for (int m = 0; m < TILE_HEIGHT; ++m) {
                __attribute__((xcl_pipeline_loop))
                rd_buf_loop_n: for (int n = 0; n < WORD_GROUP_SIZE; ++n) {
                    // should burst WORD_GROUP_SIZE in WORD beat
                    tile[m][n] = inx[TILE_HEIGHT*WORD_GROUP_PER_ROW*WORD_GROUP_SIZE*i+WORD_GROUP_PER_ROW*WORD_GROUP_SIZE*m+WORD_GROUP_SIZE*j+n];
                }
            }
            rd_loop_m: for (int m = 0; m < TILE_HEIGHT; ++m) {
                __attribute__((xcl_pipeline_loop))
                rd_loop_n: for (int n = 0; n < WORD_GROUP_SIZE; ++n) {
                    write_pipe_block(inFifo, &tile[m][n]);
                }
            }
        }
    }
}

// Write data Kernel : Write tile/window of Results to Global Memory
kernel __attribute__ ((reqd_work_group_size(1, 1, 1)))
void write_data(__global int *outx) {
    int tile[TILE_HEIGHT][WORD_GROUP_SIZE];
    wr_loop_i: for(int i = 0; i < TILE_PER_COLUMN; ++i) {
        wr_loop_j: for (int j = 0; j < WORD_GROUP_PER_ROW; ++j) {
            wr_buf_loop_m: for (int m = 0; m < TILE_HEIGHT; ++m) {
                __attribute__((xcl_pipeline_loop))
                wr_buf_loop_n: for (int n = 0; n < WORD_GROUP_SIZE; ++n) {
                    // should burst WORD_GROUP_SIZE in WORD beat
                    read_pipe_block(outFifo, &tile[m][n]);
                }
            }
            wr_loop_m: for (int m = 0; m < TILE_HEIGHT; ++m) {
                __attribute__((xcl_pipeline_loop))
                wr_loop_n: for (int n = 0; n < WORD_GROUP_SIZE; ++n) {
                    outx[TILE_HEIGHT*WORD_GROUP_PER_ROW*WORD_GROUP_SIZE*i+WORD_GROUP_PER_ROW*WORD_GROUP_SIZE*m+WORD_GROUP_SIZE*j+n] = tile[m][n];
                }
            }
        }
    }
}

// Compute kernel, currently as simple as possible because this example is focused on efficient memory access pattern.
kernel __attribute__ ((reqd_work_group_size(1, 1, 1)))
void compute(int alpha) {
    for(int i = 0; i < NUM_ROWS; ++i) {
        __attribute__((xcl_pipeline_loop))
        for (int jj = 0; jj < WORD_GROUP_PER_ROW; ++jj) {
            for (int m = 0; m < WORD_GROUP_SIZE; ++m) {
                int inTmp;
                read_pipe_block(inFifo, &inTmp);
                int outTmp = inTmp * alpha;
                write_pipe_block(outFifo, &outTmp);
            }
        }
    }
}