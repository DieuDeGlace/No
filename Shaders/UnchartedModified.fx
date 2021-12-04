/*
									UnchartedModified: 
		This is a modified version of the Uncharted 2 Tonemap found on filmicworlds, by Zackin5, and edited with chillant and has tweakable values.
		
		Full credits to John Hable for the code to use as a base, and Ian Taylor for the code used to make it run better.
		Edited by Brimson, DieuDeGlace, and Luluco250.
*/

#include "ReShade.fxh"

uniform bool U2_Lum <
	ui_label = "Use luminance";
	ui_tooltip = "Calculate tone based off each pixel's luminance value vs the RGB value.";
> = true;
uniform float U2_A <
	ui_type = "slider";
	ui_min = 0.00; ui_max = 1.00;
	ui_label = "Shoulder strength";
> = 0.22;

uniform float U2_B <
	ui_type = "slider";
	ui_min = 0.00; ui_max = 1.00;
	ui_label = "Linear strength";
> = 0.30;

uniform float U2_C <
	ui_type = "slider";
	ui_min = 0.00; ui_max = 1.00;
	ui_label = "Linear angle";
> = 0.10;

uniform float U2_D <
	ui_type = "slider";
	ui_min = 0.00; ui_max = 1.00;
	ui_label = "Toe strength";
> = 0.20;

uniform float U2_E <
	ui_type = "slider";
	ui_min = 0.00; ui_max = 1.00;
	ui_label = "Toe numerator";
> = 0.01;

uniform float U2_F <
	ui_type = "slider";
	ui_min = 0.00; ui_max = 1.00;
	ui_label = "Toe denominator";
> = 0.22;

uniform float U2_Exp <
	ui_type = "slider";
	ui_min = 1.00; ui_max = 20.00;
	ui_label = "Exposure";
> = 1.0;
uniform float Saturation
<
    ui_type = "slider";
    ui_min = 0.0;
    ui_max = 1.5;
> = 1.0;
uniform float Shadow
<
    ui_type = "slider";
    ui_min = 0.0;
    ui_max = 1.5;
> = 1.0;
uniform float U2_Gamma <
	ui_type = "slider";
	ui_min = 1.00; ui_max = 3.00;
	ui_label = "Gamma value";
	ui_tooltip = "Most monitors/images use a value of 2.2. Setting this to 1 disables the inital color space conversion from gamma to linear.";
> = 2.2;
uniform float3 FinalColoring <
	ui_type = "drag";
	ui_min = 0.00; ui_max = 50.00;
	ui_tooltip = "Most monitors/images use a value of 2.2. Setting this to 1 disables the inital color space conversion from gamma to linear.";
> = 0.0;

uniform float3 WhitePoint <
	ui_type = "drag";
	ui_min = 0.00; ui_max = 20.00;
	ui_tooltip = "Most monitors/images use a value of 2.2. Setting this to 1 disables the inital color space conversion from gamma to linear.";
> = 11.20;


//  Functions from [https://www.chilliant.com/rgb2hsv.html]
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

// Function provided by Lucas [https://github.com/luluco250]
float3 ApplySaturation(float3 color)
{
    color = RGBtoHSL(color);
    color.y *= Saturation;
    color = HSLtoRGB(color);
    return color;
}

float3 Uncharted2Tonemap(float3 x)
{
	return ((x*(U2_A*x+U2_C*U2_B)+U2_D*U2_E)/(x*(U2_A*x+U2_B)+U2_D*U2_F))-U2_E/U2_F;
}

	// Function provided by Zackin5 [https://github.com/Zackin5/Filmic-Tonemapping-ReShade/]
float3 Uncharted_Tonemap_Main(float4 pos : SV_Position, float2 texcoord : TexCoord ) : COLOR
{
	float3 texColor = (tex2D(ReShade::BackBuffer, texcoord).rgb);
	
	// Do inital de-gamma of the game image to ensure we're operating in the correct colour range.
	if( U2_Gamma > 0.00 )
		texColor = pow(texColor,U2_Gamma);
		
	texColor *= U2_Exp;  // Exposure Adjustment

	float ExposureBias = 2.0f;
	float3 curr;

	// Do tonemapping on RGB or Luminance
	if(!U2_Lum)
		curr = Uncharted2Tonemap(ExposureBias*texColor);
	else
	{
		float lum = 0.2126f * texColor[0] + 0.7152 * texColor[1] + 0.0722 * texColor[2] + 0.1;
		float3 newLum = Uncharted2Tonemap(ExposureBias*lum);
		float lumScale = newLum / lum;
		curr = texColor*lumScale;
	}

	float3 whiteScale = 1.0f/Uncharted2Tonemap(WhitePoint);
	
	//this function is provided by Lucas [https://github.com/luluco250]
	texColor = ApplySaturation(texColor);
	
	
	float3 color = curr*whiteScale;
    
	// Do the post-tonemapping gamma correction
	if( U2_Gamma > 0.00 )
		color = pow(color,Shadow/U2_Gamma)+(FinalColoring*(0.01));
				

	color = lerp(dot(color, 0.333), color, Saturation);
	
	return color;
}

technique Uncharted2Tonemap
{
	pass
	{
		VertexShader = PostProcessVS;
		PixelShader = Uncharted_Tonemap_Main;
	}
}
