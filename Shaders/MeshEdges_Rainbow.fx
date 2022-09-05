///////////////////////////////////////////////////////////////////////////////
//
//ReShade Shader: MeshEdges
//https://github.com/Daodan317081/reshade-shaders
//
//BSD 3-Clause License
//
//Copyright (c) 2018-2019, Alexander Federwisch
//All rights reserved.
//
//Redistribution and use in source and binary forms, with or without
//modification, are permitted provided that the following conditions are met:
//
//* Redistributions of source code must retain the above copyright notice, this
//  list of conditions and the following disclaimer.
//
//* Redistributions in binary form must reproduce the above copyright notice,
//  this list of conditions and the following disclaimer in the documentation
//  and/or other materials provided with the distribution.
//
//* Neither the name of the copyright holder nor the names of its
//  contributors may be used to endorse or promote products derived from
//  this software without specific prior written permission.
//
//THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
//AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
//IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
//DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
//FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
//DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
//SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
//CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
//OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
//OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
///////////////////////////////////////////////////////////////////////////////
// Lightly optimized by Marot Satil for the GShade project.
///////////////////////////////////////////////////////////////////////////////
//
//Rainbow stuff added by Ekibunnel
//https://github.com/Ekibunnel/ReShade
//
///////////////////////////////////////////////////////////////////////////////

#include "ReShade.fxh"

#ifndef MeshEdgesSpan
	#define MeshEdgesSpan 0.00000000002 // tweek this value if you only want to see outer edge
#endif

uniform float timer < source = "timer"; >;

uniform int iUIBackground <
    ui_type = "combo";
    ui_label = "Background Type";
    ui_items = "Backbuffer\0Color\0";
> = 1;

uniform float3 fUIColorBackground <
    ui_type = "color";
    ui_label = "Color Background";
> = float3(1.0, 1.0, 1.0);

uniform float3 fUIColorLines <
    ui_type = "color";
    ui_label = "Static Color Lines";
> = float3(0.0, 0.0, 0.0);

uniform float fUIStrength <
    ui_type = "slider";
    ui_label = "Strength (Alpha)";
    ui_min = 0.0; ui_max = 1.0;
    ui_step = 0.01;
> = 1.0;

uniform int fUIColorLinesType <
    ui_type = "combo";
    ui_label = "Color Type for Lines";
    ui_items = "Static\0Rainbow\0Rainbow On Depth\0";
> = 0;

uniform float fUIRainbowSpeed <
    ui_type = "slider";
    ui_label = "Rainbow Color Speed";
    ui_min = 0.0;
    ui_max = 1.0;
    ui_step = 0.001;
> = 0.085;

uniform float fUIRainbowLength <
    ui_type = "slider";
    ui_label = "Rainbow Lengt";
    ui_min = 0.0;
    ui_max = 100.0;
    ui_step = 0.01;
> = 1.0;

#define MAX2(v) max(v.x, v.y)
#define MIN2(v) min(v.x, v.y)
#define MAX4(v) max(v.x, max(v.y, max(v.z, v.w)))
#define MIN4(v) min(v.x, min(v.y, min(v.z, v.w)))

float3 HUEtoRGB(in float hue) {
	hue =  hue % 1;
    return saturate(float3(abs(hue * 6.0 - 3.0) - 1.0,
                           2.0 - abs(hue * 6.0 - 2.0),
                           2.0 - abs(hue * 6.0 - 4.0)));
}

float3 MeshEdges_PS(float4 vpos:SV_Position, float2 texcoord:TexCoord):SV_Target {
    const float3 backbuffer = tex2D(ReShade::BackBuffer, texcoord).rgb;
    const float4 pix = float4(BUFFER_PIXEL_SIZE, -BUFFER_PIXEL_SIZE);

    //Get depth of center pixel
    float c = ReShade::GetLinearizedDepth(texcoord);
    //Get depth of surrounding pixels
    float4 depthEven = float4(  ReShade::GetLinearizedDepth(texcoord + float2(0.0, pix.w)),
                                ReShade::GetLinearizedDepth(texcoord + float2(0.0, pix.y)),
                                ReShade::GetLinearizedDepth(texcoord + float2(pix.x, 0.0)),
                                ReShade::GetLinearizedDepth(texcoord + float2(pix.z, 0.0))   );

    float4 depthOdd  = float4(  ReShade::GetLinearizedDepth(texcoord + float2(pix.x, pix.w)),
                                ReShade::GetLinearizedDepth(texcoord + float2(pix.z, pix.y)),
                                ReShade::GetLinearizedDepth(texcoord + float2(pix.x, pix.y)),
                                ReShade::GetLinearizedDepth(texcoord + float2(pix.z, pix.w)) );
    
    //Normalize values
    const float2 mind = float2(MIN4(depthEven), MIN4(depthOdd));
    const float2 maxd = float2(MAX4(depthEven), MAX4(depthOdd));
    const float span = MAX2(maxd) - MIN2(mind) - MeshEdgesSpan;
    c /= span;
    depthEven /= span;
    depthOdd /= span;
    //Calculate the distance of the surrounding pixels to the center
    const float4 diffsEven = abs(depthEven - c);
    const float4 diffsOdd = abs(depthOdd - c);
    //Calculate the difference of the (opposing) distances
    const float2 retVal = float2( max(abs(diffsEven.x - diffsEven.y), abs(diffsEven.z - diffsEven.w)),
                            max(abs(diffsOdd.x - diffsOdd.y), abs(diffsOdd.z - diffsOdd.w))     );

    const float lineWeight = MAX2(retVal);

	float3 FinalColorLines = fUIColorLines;

	if (fUIColorLinesType == 1)
		FinalColorLines = HUEtoRGB(smoothstep(0.0,360.0, (timer*fUIRainbowSpeed) % 360.0));

	if (fUIColorLinesType == 2)
		FinalColorLines = HUEtoRGB(((ReShade::GetLinearizedDepth(texcoord)*fUIRainbowLength)+(timer*0.001*fUIRainbowSpeed)));	

	if (iUIBackground == 0)
		return lerp(backbuffer, FinalColorLines, lineWeight * fUIStrength);
	else
		return lerp(fUIColorBackground, FinalColorLines, lineWeight * fUIStrength);
}

technique MeshEdges
<
	ui_label = "MeshEdges Rainbow";
	ui_tooltip =
		"Draw the polygon edges of a mesh and its outline.\n"
		"\n"
		"Be sure to have correctly configured your global preprocessor definition\n"
		"to have a working depth buffer if you want to use 'Rainbow on depth'\n";
> {
    pass {
        VertexShader = PostProcessVS; 
        PixelShader = MeshEdges_PS; 
        /* RenderTarget = BackBuffer */
    }
}
