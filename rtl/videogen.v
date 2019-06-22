// vim:ts=4:shiftwidth=4:expandtab
//
// Copyright (C) 2015-2017  Markus Hiienkari <mhiienka@niksula.hut.fi>
//
// This file is part of Open Source Scan Converter project.
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

`include "lat_tester_includes.v"

module videogen (
    input clk27,
    input reset_n,
    input lt_active,
    input [1:0] lt_mode,
    output [7:0] R_out,
    output [7:0] G_out,
    output [7:0] B_out,
    output reg HSYNC_out,
    output reg VSYNC_out,
    output PCLK_out,
    output reg ENABLE_out
);

//Parameters for 720x480@59.94Hz (858px x 525lines, pclk 27MHz -> 59.94Hz)
parameter   H_SYNCLEN       =   10'd62;
parameter   H_BACKPORCH     =   10'd60;
parameter   H_ACTIVE        =   10'd720;
parameter   H_FRONTPORCH    =   10'd16;
parameter   H_TOTAL         =   10'd858;

parameter   V_SYNCLEN       =   10'd6;
parameter   V_BACKPORCH     =   10'd30;
parameter   V_ACTIVE        =   10'd480;
parameter   V_FRONTPORCH    =   10'd9;
parameter   V_TOTAL         =   10'd525;

parameter   H_OVERSCAN      =   10'd40; //at both sides
parameter   V_OVERSCAN      =   10'd16; //top and bottom
parameter   H_AREA          =   10'd640;
parameter   V_AREA          =   10'd448;
parameter   H_GRADIENT      =   10'd512;
parameter   V_GRADIENT      =   10'd256;
parameter   V_GRAYRAMP      =   10'd84;
parameter   H_BORDER        =   ((H_AREA-H_GRADIENT)>>1);
parameter   V_BORDER        =   ((V_AREA-V_GRADIENT)>>1);

parameter   X_START     =   H_SYNCLEN + H_BACKPORCH;
parameter   Y_START     =   V_SYNCLEN + V_BACKPORCH;

//Counters
reg [9:0] h_cnt; //max. 1024
reg [9:0] v_cnt; //max. 1024

reg [9:0] xpos;
reg [9:0] ypos;

assign PCLK_out = clk27;
//R, G and B should be 0 outside of active area
assign R_out = ENABLE_out ? V_gen : 8'h00;
assign G_out = ENABLE_out ? V_gen : 8'h00;
assign B_out = ENABLE_out ? V_gen : 8'h00;

reg [7:0] V_gen;

//reg [7:0] lfsr_frame;
reg [7:0] lfsr_pixel;
//assign frame_feedback =  ! (lfsr_frame[7] ^ lfsr_frame[3]);
assign pixel_feedback =  ! (lfsr_pixel[7] ^ lfsr_pixel[3]);


//HSYNC gen (negative polarity)
always @(posedge clk27 or negedge reset_n)
begin
    if (!reset_n) begin
        h_cnt <= 0;
        HSYNC_out <= 0;
    end else begin
        //Hsync counter
        if (h_cnt < H_TOTAL-1)
            h_cnt <= h_cnt + 1'b1;
        else
            h_cnt <= 0;

        //Hsync signal
        HSYNC_out <= (h_cnt < H_SYNCLEN) ? 1'b0 : 1'b1;
    end
end

//VSYNC gen (negative polarity)
always @(posedge clk27 or negedge reset_n)
begin
    if (!reset_n) begin
        v_cnt <= 0;
        VSYNC_out <= 0;
    end else begin
        //Vsync counter
        if (h_cnt == H_TOTAL-1) begin
            if (v_cnt < V_TOTAL-1)
                v_cnt <= v_cnt + 1'b1;
            else

//			lfsr_frame <= {
//				lfsr_frame[6],lfsr_frame[5],
//				lfsr_frame[4],lfsr_frame[3],
//				lfsr_frame[2],lfsr_frame[1],
//				lfsr_frame[0], frame_feedback};	

                v_cnt <= 0;
        end


        //Vsync signal
        VSYNC_out <= (v_cnt < V_SYNCLEN) ? 1'b0 : 1'b1;
    end
end

//Data and ENABLE gen
always @(posedge clk27 or negedge reset_n)
begin
    if (!reset_n) begin
        V_gen <= 8'h00;
        ENABLE_out <= 1'b0;
    end else begin
        if (lt_active) begin
            case (lt_mode)
                default: begin
                    V_gen <= 8'h00;
                end
                `LT_POS_TOPLEFT: begin
                    V_gen <= ((h_cnt < (X_START+(H_ACTIVE/`LT_WIDTH_DIV))) && (v_cnt < (Y_START+(V_ACTIVE/`LT_HEIGHT_DIV)))) ? 8'hff : 8'h00;
                end
                `LT_POS_CENTER: begin
                    V_gen <= ((h_cnt >= (X_START+(H_ACTIVE/2)-(H_ACTIVE/(`LT_WIDTH_DIV*2)))) && (h_cnt < (X_START+(H_ACTIVE/2)+(H_ACTIVE/(`LT_WIDTH_DIV*2)))) && (v_cnt >= (Y_START+(V_ACTIVE/2)-(V_ACTIVE/(`LT_HEIGHT_DIV*2)))) && (v_cnt < (Y_START+(V_ACTIVE/2)+(V_ACTIVE/(`LT_HEIGHT_DIV*2))))) ? 8'hff : 8'h00;
                end
                `LT_POS_BOTTOMRIGHT: begin
                    V_gen <= ((h_cnt >= (X_START+H_ACTIVE-(H_ACTIVE/`LT_WIDTH_DIV))) && (v_cnt >= (Y_START+V_ACTIVE-(V_ACTIVE/`LT_HEIGHT_DIV)))) ? 8'hff : 8'h00;
                end
            endcase
        end else begin
            if ((h_cnt < X_START+H_OVERSCAN) || (h_cnt >= X_START+H_OVERSCAN+H_AREA) || (v_cnt < Y_START+V_OVERSCAN) || (v_cnt >= Y_START+V_OVERSCAN+V_AREA))
                V_gen <= (h_cnt[0] ^ v_cnt[0]) ? 8'hff : 8'h00;
            else if ((h_cnt < X_START+H_OVERSCAN+H_BORDER) || (h_cnt >= X_START+H_OVERSCAN+H_AREA-H_BORDER) || (v_cnt < Y_START+V_OVERSCAN+V_BORDER) || (v_cnt >= Y_START+V_OVERSCAN+V_AREA-V_BORDER))
                V_gen <= 8'h50;
            else
                V_gen <= lfsr_pixel[7] ? 8'h20:8'hdf;

                lfsr_pixel <= {
                    lfsr_pixel[6],lfsr_pixel[5],
                    lfsr_pixel[4],lfsr_pixel[3],
                    lfsr_pixel[2],lfsr_pixel[1],
                    lfsr_pixel[0], pixel_feedback};
        end

        ENABLE_out <= (h_cnt >= X_START && h_cnt < X_START + H_ACTIVE && v_cnt >= Y_START && v_cnt < Y_START + V_ACTIVE);
    end
end

endmodule
