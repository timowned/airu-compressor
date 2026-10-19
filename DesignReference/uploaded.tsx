const assetPathPrefix = "https://www.figma.com/api/mcp/asset/371030eb-89a4-4228-a1f5-1af32d1fd3ac";
const imgFolder = `${assetPathPrefix}/be026.png`;
const imgVector = `${assetPathPrefix}/beeb3.svg`;
const imgVector1 = `${assetPathPrefix}/feec3.svg`;

type WindowControlsStandardProps = {
  className?: string;
  active?: "True";
  mode?: "Dark";
};

function WindowControlsStandard({ className, active = "True", mode = "Dark" }: WindowControlsStandardProps) {
  return (
    <div className={className || "content-stretch flex gap-[9px] items-center pointer-events-none pr-[8px] relative"} data-node-id="4002:1396">
      <div className="relative rounded-[100px] shrink-0 size-[14px]" data-node-id="4002:1397" data-name="Close">
        <div aria-hidden className="absolute bg-[#f06e6a] inset-0 rounded-[100px]" />
        <div className="absolute inset-0 rounded-[inherit] shadow-[inset_0px_1.25px_0.5px_-0.75px_#999,inset_0px_-1.25px_0.5px_-0.75px_#808080,inset_0px_5px_4px_-3px_#262626,inset_0px_0px_3px_0px_rgba(153,31,0,0.6),inset_0px_17px_4px_-10px_rgba(153,31,0,0.4)]" />
      </div>
      <div className="relative rounded-[100px] shrink-0 size-[14px]" data-node-id="4002:1398" data-name="Minimize">
        <div aria-hidden className="absolute bg-[#ffcd30] inset-0 rounded-[100px]" />
        <div className="absolute inset-0 rounded-[inherit] shadow-[inset_0px_1.25px_0.5px_-0.75px_#999,inset_0px_-1.25px_0.5px_-0.75px_#808080,inset_0px_5px_4px_-3px_#161616,inset_0px_0px_3px_0px_#4d2e0f,inset_0px_17px_4px_-10px_#4d2e0f]" />
      </div>
      <div className="relative rounded-[100px] shrink-0 size-[14px]" data-node-id="4002:1399" data-name="Zoom">
        <div aria-hidden className="absolute bg-[#58c73b] inset-0 rounded-[100px]" />
        <div className="absolute inset-0 rounded-[inherit] shadow-[inset_0px_1.25px_0.5px_-0.75px_#999,inset_0px_-1.25px_0.5px_-0.75px_#808080,inset_0px_5px_4px_-3px_#262626,inset_0px_0px_3px_0px_rgba(17,51,0,0.8),inset_0px_17px_4px_-10px_rgba(17,51,0,0.6)]" />
      </div>
    </div>
  );
}

export default function Uploaded() {
  return (
    <div className="bg-[#151515] content-stretch flex flex-col items-center overflow-clip relative rounded-[22px] size-full" data-node-id="4010:3416" data-name="Uploaded">
      <div className="content-stretch flex flex-col gap-[10px] items-start p-[22px] relative shrink-0 w-full" data-node-id="4010:3417">
        <WindowControlsStandard className="content-stretch flex gap-[9px] items-center pointer-events-none pr-[8px] relative shrink-0" />
        <div className="-translate-x-1/2 absolute bg-[rgba(255,255,255,0.05)] content-stretch flex items-center left-1/2 p-[4px] rounded-[67px] top-[14px]" data-node-id="4010:3419">
          <div className="bg-[rgba(0,0,0,0.3)] content-stretch flex items-center justify-center px-[12px] py-[11px] relative rounded-[39px] shrink-0" data-node-id="4010:3420">
            <div className="[text-box-edge:cap_alphabetic] [text-box-trim:trim-both] [word-break:break-word] flex flex-col font-['SF_Pro:Regular'] font-normal justify-center leading-[0] relative shrink-0 text-[14px] text-center text-white whitespace-nowrap" data-node-id="4010:3421" style={{ fontVariationSettings: '"wdth" 100' }}>
              <p className="leading-[16px]">Auto</p>
            </div>
          </div>
          <div className="content-stretch flex items-center justify-center px-[12px] py-[11px] relative rounded-[39px] shrink-0" data-node-id="4010:3422">
            <div className="[text-box-edge:cap_alphabetic] [text-box-trim:trim-both] [word-break:break-word] flex flex-col font-['SF_Pro:Regular'] font-normal justify-center leading-[0] relative shrink-0 text-[14px] text-center text-white whitespace-nowrap" data-node-id="4010:3423" style={{ fontVariationSettings: '"wdth" 100' }}>
              <p className="leading-[16px]">Manual</p>
            </div>
          </div>
        </div>
      </div>
      <div className="content-stretch flex flex-[1_0_0] flex-col items-center justify-center min-h-px p-[20px] relative w-full" data-node-id="4010:3424">
        <div className="content-stretch flex flex-[1_0_0] flex-col items-center justify-between min-h-px overflow-clip relative w-full" data-node-id="4010:3425">
          <div className="content-stretch flex flex-col items-start relative shrink-0 w-full" data-node-id="4010:3426">
            <div className="bg-white h-px opacity-10 relative shrink-0 w-full" data-node-id="4010:3427" />
            <div className="content-stretch flex items-center justify-between py-[20px] relative shrink-0 w-full" data-node-id="4010:3428">
              <div className="content-stretch flex items-center justify-center relative shrink-0" data-node-id="4010:3429">
                <div className="[text-box-edge:cap_alphabetic] [text-box-trim:trim-both] [word-break:break-word] flex flex-col font-['SF_Pro:Light'] font-[274.31500244140625] justify-center leading-[0] relative shrink-0 text-[13px] text-center text-white whitespace-nowrap" data-node-id="4010:3430" style={{ fontVariationSettings: '"wdth" 100' }}>
                  <p className="leading-[16px]">[File name]</p>
                </div>
              </div>
              <div className="content-stretch flex items-center relative shrink-0" data-node-id="4010:3548">
                <div className="[text-box-edge:cap_alphabetic] [text-box-trim:trim-both] [word-break:break-word] flex flex-col font-['SF_Pro:Light'] font-[274.31500244140625] justify-center leading-[0] relative shrink-0 text-[13px] text-center text-white whitespace-nowrap" data-node-id="4010:3549" style={{ fontVariationSettings: '"wdth" 100' }}>
                  <p className="leading-[16px]">2.2MB</p>
                </div>
              </div>
            </div>
            <div className="bg-white h-px opacity-10 relative shrink-0 w-full" data-node-id="4010:3437" />
            <div className="content-stretch flex items-center justify-between py-[20px] relative shrink-0 w-full" data-node-id="4010:3438">
              <div className="content-stretch flex items-center justify-center relative shrink-0" data-node-id="4010:3439">
                <div className="[text-box-edge:cap_alphabetic] [text-box-trim:trim-both] [word-break:break-word] flex flex-col font-['SF_Pro:Light'] font-[274.31500244140625] justify-center leading-[0] relative shrink-0 text-[13px] text-center text-white whitespace-nowrap" data-node-id="4010:3440" style={{ fontVariationSettings: '"wdth" 100' }}>
                  <p className="leading-[16px]">[File name]</p>
                </div>
              </div>
              <div className="content-stretch flex items-center relative shrink-0" data-node-id="4010:3441">
                <div className="[text-box-edge:cap_alphabetic] [text-box-trim:trim-both] [word-break:break-word] flex flex-col font-['SF_Pro:Light'] font-[274.31500244140625] justify-center leading-[0] relative shrink-0 text-[13px] text-center text-white whitespace-nowrap" data-node-id="4010:3442" style={{ fontVariationSettings: '"wdth" 100' }}>
                  <p className="leading-[16px]">2.2MB</p>
                </div>
              </div>
            </div>
            <div className="bg-white h-px opacity-10 relative shrink-0 w-full" data-node-id="4010:3447" />
            <div className="content-stretch flex h-[51px] items-center justify-between py-[20px] relative shrink-0 w-full" data-node-id="4010:3448">
              <div className="content-stretch flex items-center justify-center relative shrink-0" data-node-id="4010:3449">
                <div className="[text-box-edge:cap_alphabetic] [text-box-trim:trim-both] [word-break:break-word] flex flex-col font-['SF_Pro:Light'] font-[274.31500244140625] justify-center leading-[0] relative shrink-0 text-[13px] text-center text-white whitespace-nowrap" data-node-id="4010:3450" style={{ fontVariationSettings: '"wdth" 100' }}>
                  <p className="leading-[16px]">[File name]</p>
                </div>
              </div>
              <div className="content-stretch flex items-center relative shrink-0" data-node-id="4010:3551">
                <div className="[text-box-edge:cap_alphabetic] [text-box-trim:trim-both] [word-break:break-word] flex flex-col font-['SF_Pro:Light'] font-[274.31500244140625] justify-center leading-[0] relative shrink-0 text-[13px] text-center text-white whitespace-nowrap" data-node-id="4010:3552" style={{ fontVariationSettings: '"wdth" 100' }}>
                  <p className="leading-[16px]">2.2MB</p>
                </div>
              </div>
            </div>
            <div className="bg-white h-px opacity-10 relative shrink-0 w-full" data-node-id="4010:3458" />
            <div className="content-stretch flex h-[51px] items-center justify-between py-[20px] relative shrink-0 w-full" data-node-id="4010:3459">
              <div className="content-stretch flex items-center justify-center relative shrink-0" data-node-id="4010:3460">
                <div className="[text-box-edge:cap_alphabetic] [text-box-trim:trim-both] [word-break:break-word] flex flex-col font-['SF_Pro:Light'] font-[274.31500244140625] justify-center leading-[0] relative shrink-0 text-[13px] text-center text-white whitespace-nowrap" data-node-id="4010:3461" style={{ fontVariationSettings: '"wdth" 100' }}>
                  <p className="leading-[16px]">[File name]</p>
                </div>
              </div>
              <div className="content-stretch flex items-center relative shrink-0" data-node-id="4010:3554">
                <div className="[text-box-edge:cap_alphabetic] [text-box-trim:trim-both] [word-break:break-word] flex flex-col font-['SF_Pro:Light'] font-[274.31500244140625] justify-center leading-[0] relative shrink-0 text-[13px] text-center text-white whitespace-nowrap" data-node-id="4010:3555" style={{ fontVariationSettings: '"wdth" 100' }}>
                  <p className="leading-[16px]">2.2MB</p>
                </div>
              </div>
            </div>
            <div className="bg-white h-px opacity-10 relative shrink-0 w-full" data-node-id="4010:3469" />
          </div>
          <div className="content-stretch flex items-end justify-between relative shrink-0 w-full" data-node-id="4010:3470">
            <div className="content-stretch flex flex-col gap-[10px] items-start relative shrink-0" data-node-id="4012:3841">
              <div className="[text-box-edge:cap_alphabetic] [text-box-trim:trim-both] [word-break:break-word] flex flex-col font-['SF_Pro:Regular'] font-normal justify-center leading-[0] relative shrink-0 text-[13px] text-[rgba(255,255,255,0.8)] text-center whitespace-nowrap" data-node-id="4012:3842" style={{ fontVariationSettings: '"wdth" 100' }}>
                <p className="leading-[16px]">Compress to</p>
              </div>
              <div className="bg-[#131313] content-stretch flex flex-col items-start p-px relative rounded-[10px] shrink-0" data-node-id="4012:3843">
                <div className="bg-[#1e1e1e] border border-[#272727] border-solid content-stretch flex gap-[10px] h-[36px] items-center justify-center overflow-clip pl-[10px] pr-[2px] relative rounded-[9px] shrink-0 w-full" data-node-id="4012:3844">
                  <div className="[word-break:break-word] content-stretch flex gap-[6px] items-center leading-[16px] relative shrink-0 text-[13px] text-white whitespace-nowrap" data-node-id="4012:3845">
                    <p className="[text-box-edge:cap_alphabetic] [text-box-trim:trim-both] font-['SF_Pro:Medium'] font-[510] overflow-hidden relative shrink-0 text-ellipsis" data-node-id="4012:3846" style={{ fontVariationSettings: '"wdth" 100' }}>
                      JPEG
                    </p>
                    <p className="[text-box-edge:cap_alphabetic] [text-box-trim:trim-both] font-['SF_Pro:Light'] font-[274.31500244140625] opacity-50 overflow-hidden relative shrink-0 text-ellipsis" data-node-id="4012:3847" style={{ fontVariationSettings: '"wdth" 100' }}>
                      Airy
                    </p>
                  </div>
                  <div className="overflow-clip relative rounded-[6.5px] shrink-0 size-[30px]" data-node-id="4012:3848" data-name="Combo Box Button">
                    <div className="absolute bg-[rgba(255,255,255,0.08)] inset-0" data-node-id="4012:3849" data-name="Button BG" />
                    <div className="[word-break:break-word] absolute flex flex-col font-['SF_Pro:Bold'] font-bold inset-0 justify-center leading-[0] text-[length:var(--combo-button\/font-size---chevron,11px)] text-center text-white" data-node-id="4012:3850" style={{ fontVariationSettings: '"wdth" 100', fontFeatureSettings: '"ss15" 1' }}>
                      <SFSymbol>{`Image(systemName: "chevron.down")`}</SFSymbol>
                    </div>
                  </div>
                </div>
              </div>
            </div>
            <div className="content-stretch flex gap-[12px] items-center relative shrink-0" data-node-id="4011:3714">
              <div className="bg-[#131313] content-stretch flex flex-col items-start p-px relative rounded-[10px] shrink-0" data-node-id="4011:3715">
                <div className="bg-[#1e1e1e] border border-[#272727] border-solid content-stretch flex h-[36px] items-center justify-center overflow-clip px-[11px] relative rounded-[9px] shrink-0 w-full" data-node-id="4011:3716">
                  <div className="h-[10.757px] relative shrink-0 w-[14px]" data-node-id="4011:3717" data-name="Vector">
                    <img alt="" className="absolute block inset-0 max-w-none size-full" src={imgVector} />
                  </div>
                </div>
              </div>
              <div className="content-stretch flex gap-[10px] h-[36px] items-center relative rounded-[67px] shrink-0" data-node-id="4011:3718">
                <div className="content-stretch flex gap-[4px] items-center justify-center relative rounded-[39px] shrink-0" data-node-id="4011:3719">
                  <div className="content-stretch flex items-center p-[1.778px] relative shrink-0" data-node-id="4011:3720" data-name="Icon">
                    <div className="relative shrink-0 size-[12.444px]" data-node-id="I4011:3720;4356:10693" data-name="Folder">
                      <img alt="" className="absolute inset-0 max-w-none object-cover pointer-events-none size-full" src={imgFolder} />
                    </div>
                  </div>
                  <div className="[text-box-edge:cap_alphabetic] [text-box-trim:trim-both] [word-break:break-word] flex flex-col font-['SF_Pro:Regular'] font-normal justify-center leading-[0] relative shrink-0 text-[12px] text-center text-white whitespace-nowrap" data-node-id="4011:3721" style={{ fontVariationSettings: '"wdth" 100' }}>
                    <p className="leading-[16px]">timparanitsa</p>
                  </div>
                </div>
                <div className="h-[8px] relative shrink-0 w-[4px]" data-node-id="4011:3722">
                  <div className="absolute inset-[-4.42%_-17.68%_-4.42%_-8.84%]">
                    <img alt="" className="block max-w-none size-full" src={imgVector1} />
                  </div>
                </div>
                <div className="content-stretch flex gap-[4px] items-center justify-center relative rounded-[39px] shrink-0" data-node-id="4011:3723">
                  <div className="content-stretch flex items-center p-[1.778px] relative shrink-0" data-node-id="4011:3724" data-name="Icon">
                    <div className="relative shrink-0 size-[12.444px]" data-node-id="I4011:3724;4356:10693" data-name="Folder">
                      <img alt="" className="absolute inset-0 max-w-none object-cover pointer-events-none size-full" src={imgFolder} />
                    </div>
                  </div>
                  <div className="[text-box-edge:cap_alphabetic] [text-box-trim:trim-both] [word-break:break-word] flex flex-col font-['SF_Pro:Regular'] font-normal justify-center leading-[0] relative shrink-0 text-[12px] text-center text-white whitespace-nowrap" data-node-id="4011:3725" style={{ fontVariationSettings: '"wdth" 100' }}>
                    <p className="leading-[16px]">Desktop</p>
                  </div>
                </div>
              </div>
            </div>
            <div className="bg-[#666] content-stretch flex flex-col items-start p-px relative rounded-[10px] shrink-0" data-node-id="4010:3544">
              <div className="bg-[#ededed] border border-[#131313] border-solid content-stretch flex h-[36px] items-center justify-center overflow-clip px-[10px] relative rounded-[9px] shrink-0 w-full" data-node-id="4010:3545">
                <p className="[text-box-edge:cap_alphabetic] [text-box-trim:trim-both] [word-break:break-word] font-['SF_Pro:Medium'] font-[510] leading-[16px] overflow-hidden relative shrink-0 text-[13px] text-black text-ellipsis whitespace-nowrap" data-node-id="4010:3546" style={{ fontVariationSettings: '"wdth" 100' }}>
                  Airufy
                </p>
              </div>
            </div>
          </div>
        </div>
      </div>
      <div className="-translate-x-1/2 absolute bg-[rgba(255,255,255,0.05)] content-stretch flex items-center justify-center left-[calc(50%+280px)] p-[5px] rounded-[67px] size-[40px] top-[14px]" data-node-id="4010:3493">
        <div className="grid-cols-[max-content] grid-rows-[max-content] inline-grid leading-[0] place-items-start relative shrink-0" data-node-id="4010:3494">
          <div className="bg-[#afafaf] col-1 h-[16px] ml-[7px] mt-0 relative row-1 w-[1.6px]" data-node-id="4010:3495" />
          <div className="col-1 flex h-[1.6px] items-center justify-center ml-0 mt-[7px] relative row-1 w-[16px]" data-node-id="4010:3496">
            <div className="flex-none rotate-90">
              <div className="bg-[#afafaf] h-[16px] relative w-[1.6px]" />
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

SUPER CRITICAL: The generated React+Tailwind code MUST be converted to match the target project's technology stack and styling system.
1. Analyze the target codebase to identify: technology stack, styling approach, component patterns, and design tokens
2. Convert React syntax to the target framework/library
3. Transform all Tailwind classes to the target styling system while preserving exact visual design
4. Follow the project's existing patterns and conventions
DO NOT install any Tailwind as a dependency unless the user instructs you to do so.


Node ids have been added to the code as data attributes, e.g. `data-node-id="1:2"`.

The generated code contains image and SVG URL constants, e.g. const image = `${assetPathPrefix}/<asset file name>`, where assetPathPrefix is declared once at the top of the code and every asset URL interpolates it. These URLs are temporary download sources and expire after 7 days. Download each asset into the project with curl -L, then replace its URL in the generated code with a reference to the downloaded asset. Never use the temporary URLs as runtime image sources.
