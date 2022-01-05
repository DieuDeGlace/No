/*
									UnchartedModified: 
		This is a modified version of the Uncharted 2 Tonemap found on filmicworlds and edited with chillant and has tweakable values.
		
		Full credits to John Hable for the code to use as a base, and Ian Taylor for the code used to make it run better.
		Edited by Brimson and DieuDeGlace.
*/

#include "ReShade.fxh"

uniform bool Luminance <
	ui_label = "Use luminance";
	ui_tooltip = "Calculate tone based off each pixel's luminance value vs the RGB value.";
> = true;

uniform float Function1 <
	ui_type = "slider";
	ui_min = 0.0;
	ui_max = 6.0;
> = 1.00;

uniform float Function2 <
	ui_type = "slider";
	ui_min = 0.0;
	ui_max = 4.0;
> = 1.00;
uniform float Saturation
<
    ui_type = "slider";
    ui_min = 0.0;
    ui_max = 1.5;
> = 1.0;
uniform float Gamma <
	ui_type = "slider";
	ui_min = 1.0; ui_max = 3.0;
	ui_tooltip = "Most monitors/images use a value of 2.2. Setting this to 1 disables the inital color space conversion from gamma to linear.";
> = 2.2;
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

// Functions from Unity's Built-In Shaders, [http://chilliant.blogspot.com.au/2012/08/srgb-approximations-for-hlsl.html?m=1]

float3 GammaToLinearSpace (float3 sRGB)
{
    return sRGB * (sRGB * (sRGB * 0.3 + 0.68) + 0.01);
}

float3 LinearToGammaSpace (float3 linRGB)
{
    linRGB = max(linRGB, 0.0);
    return max(1.08 * pow(linRGB, 0.47)+(FinalColoring*(0.01)) - 0.015, 0.0);
}
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
	float Epsilon = 1e-10;
    // Based on work by Sam Hocevar and Emil Persson
    float4 P = (RGB.g < RGB.b) ? float4(RGB.bg, -1.0, 2.0/3.0) : float4(RGB.gb, 0.0, -1.0/3.0);
    float4 Q = (RGB.r < P.x) ? float4(P.xyw, RGB.r) : float4(RGB.r, P.yzx);
    float C = Q.x - min(Q.w, Q.y);
    float H = abs((Q.w - Q.y) / (6 * C + Epsilon) + Q.z);
    return float3(H, C, Q.x);
}

float3 RGBtoHCY(in float3 RGB)
  {
    // The weights of RGB contributions to luminance.
	// Should sum to unity.


	float3 HCYwts = float3(0.299, 0.587, 0.114);
	float Epsilon = 1e-10;
    // Corrected by David Schaeffer
    float3 HCV = RGBtoHCV(RGB);
    float Y = dot(RGB, HCYwts);
    float Z = dot(HUEtoRGB(HCV.x), HCYwts);
    if (Y < Z)
    {
      HCV.y *= Z / (Epsilon + Y);
    }
    else
    {
      HCV.y *= (1 - Z) / (Epsilon + 1 - Y);
    }
    return float3(HCV.x, HCV.y, Y);
  }

float3 HCYtoRGB(in float3 HCY)
  {
	float3 HCYwts = float3(0.299, 0.587, 0.114);
    float3 RGB = HUEtoRGB(HCY.x);
    float Z = dot(RGB, HCYwts);
    if (HCY.z < Z)
    {
        HCY.y *= HCY.z / Z;
    }
    else if (Z < 1)
    {
        HCY.y *= (1 - HCY.z) / (1 - Z);
    }
    return (RGB - Z) * HCY.y + HCY.z;
  }
// Function provided by Lucas [https://github.com/luluco250]
float3 ApplySaturation(float3 color)
{
    color = RGBtoHCY(color);
    color.y *= Saturation;
    color = HCYtoRGB(color);
    return color;
}

// Function provided via [http://filmicworlds.com/blog/filmic-tonemapping-operators/]
float3 Uncharted2Tonemap(float3 x)
{	
	float A = 0.15;
	float B = 0.50;
	float C = 0.10;
	float D = 0.20;
	float E = 0.02;
	float F = 0.30;
	float W = 11.2;
	return ((x*(A*x+C*B)+D*E)/(x*(A*x+B)+D*F))-(E/F);

}
float3 LuminanceTonemap(float3 texColor)
{
    float ExposureBias = 2.0;
    float lum = 0.2126 * texColor.r + 0.7152 * texColor.g + 0.0722 * texColor.b + 1e-37;
    float3 newLum = Uncharted2Tonemap(ExposureBias*lum);
    float lumScale = newLum / lum;
    return texColor*lumScale;
}

float3 ColorFilmicToneMappingPass(float4 position : SV_Position, float2 texcoord : TexCoord) : SV_Target
{
    float3 texColor = GammaToLinearSpace(tex2D(ReShade::BackBuffer, texcoord).rgb);
    texColor=ApplySaturation(texColor);
    texColor = Gamma > 0.0 ? pow(abs(texColor),Gamma) : texColor;

    texColor *= Function1;  // Exposure Adjustment

    float ExposureBias = 2.0;
    float3 curr;
    // Do tonemapping on RGB or Luminance
    curr = Luminance
        ? LuminanceTonemap(texColor)
        : Uncharted2Tonemap(ExposureBias*texColor);

    float3 whiteScale = 1.0/Uncharted2Tonemap(WhitePoint);

    float3 color = curr*whiteScale;

    color = Gamma > 0.0 ? pow(abs(color), Function2 / Gamma) : color;
    

    return LinearToGammaSpace(color);
}
technique Uncharted2Mod
{
	pass
	{
		VertexShader = PostProcessVS;
		PixelShader = ColorFilmicToneMappingPass;
	}
}
