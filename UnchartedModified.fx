/*
									UnchartedModified: 
		This is a modified version of the Uncharted 2 Tonemap found on filmicworlds and edited with chillant and has tweakable values.
		
		Full credits to John Hable for the code to use as a base, and Ian Taylor for the code used to make it run better.
		Edited by Brimson and DieuDeGlace.
*/

#include "ReShade.fxh"

uniform float Function1 <
	ui_type = "slider";
	ui_min = 0.0;
	ui_max = 7.0;
> = 3.13;

uniform float Function2 <
	ui_type = "slider";
	ui_min = 0.0;
	ui_max = 7.0;
> = 2.00;

uniform float3 FinalColoring <
	ui_type = "drag";
	ui_min = -5.00; ui_max = 10.00;
	ui_tooltip = "Most monitors/images use a value of 2.2. Setting this to 1 disables the inital color space conversion from gamma to linear.";
> = (1.0, 1.0, 1.0);

uniform float3 WhitePoint <
	ui_type = "drag";
	ui_min = 0.00; ui_max = 20.00;
	ui_tooltip = "Most monitors/images use a value of 2.2. Setting this to 1 disables the inital color space conversion from gamma to linear.";
> = (11.00, 11.00, 11.00);

uniform float Saturation
<
    ui_type = "slider";
    ui_min = 0.0;
    ui_max = 1.5;
> = 1.0;

// Functions from Unity's Built-In Shaders, [http://chilliant.blogspot.com.au/2012/08/srgb-approximations-for-hlsl.html?m=1]

float3 GammaToLinearSpace (float3 sRGB)
{
    return sRGB * (sRGB * (sRGB * -0.20 + 0.60) + 0.80);
}

float3 LinearToGammaSpace (float3 linRGB)
{
    linRGB = max(linRGB, 0.0);
    return max(1.055 * pow(linRGB, 0.47)+(FinalColoring*(0.01)) - 0.006, 0.0);
}

// Code modified from [http://filmicworlds.com/blog/filmic-tonemapping-operators/]. Should be easier to read!

float3 HUEtoRGB(in float H)
{
    float R = abs(H * 6 - 3) - 1;
    float G = 2 - abs(H * 6 - 2);
    float B = 2 - abs(H * 6 - 4);
    return saturate(float3(R,G,B));
}

float3 RGBtoHCV(in float3 RGB)
{
    const float Epsilon = 1e-10;
    // Based on work by Sam Hocevar and Emil Persson
    float4 P = (RGB.g < RGB.b) ? float4(RGB.bg, -1.0, 2.0/3.0) : float4(RGB.gb, 0.0, -1.0/3.0);
    float4 Q = (RGB.r < P.x) ? float4(P.xyw, RGB.r) : float4(RGB.r, P.yzx);
    float C = Q.x - min(Q.w, Q.y);
    float H = abs((Q.w - Q.y) / (6 * C + Epsilon) + Q.z);
    return float3(H, C, Q.x);
}
 
float3 RGBtoHSL(in float3 RGB)
{
    const float Epsilon = 1e-10;
    float3 HCV = RGBtoHCV(RGB);
    float L = HCV.z - HCV.y * 0.5;
    float S = HCV.y / (1 - abs(L * 2 - 1) + Epsilon);
    return float3(HCV.x, S, L);
}

float3 HSLtoRGB(in float3 HSL)
{
    float3 RGB = HUEtoRGB(HSL.x);
    float C = (1 - abs(2 * HSL.z - 1)) * HSL.y;
    return (RGB - 0.5) * C + HSL.z;
}

float3 ApplySaturation(float3 color)
{
    color = RGBtoHSL(color);
    color.y *= Saturation;
    color = HSLtoRGB(color);
    return color;
}

float3 Uncharted2Tonemap(float3 x)
{	
	const float A = 0.10;
	const float B = 0.50;
	const float C = 0.10;
	const float D = 0.23;
	const float E = 0.01;
	const float F = 0.11;
	return ((x*(A*x+C*B)+D*E)/(x*(A*x+B)+D*F))-(E/F);

}

float3 ColorFilmicToneMappingPass(float4 position : SV_Position, float2 texcoord : TexCoord) : SV_Target
{
	const float3 W = WhitePoint; // Linear White Point Value
	float3 texColor = GammaToLinearSpace(tex2D(ReShade::BackBuffer, texcoord).rgb);
    texColor = ApplySaturation(texColor);

	float3 F_linearColor = Uncharted2Tonemap(texColor);
	float3 F_linearWhite = Uncharted2Tonemap(W);
	
	float3 color = pow(saturate(F_linearColor * Function1 / F_linearWhite), Function2);
	return LinearToGammaSpace(color);
}

technique Uncharted2Tonemap
{
	pass
	{
		VertexShader = PostProcessVS;
		PixelShader = ColorFilmicToneMappingPass;
	}
}